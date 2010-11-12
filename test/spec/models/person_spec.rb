require_relative '../spec_helper'

describe Person do
  before(:each) do
    Person.delete_ldap_base
    Person.process_ldif Rails.root.join("spec","fixtures","root.ldif")
  end

  it "should have no conditions" do
    p = Person.new
    p.class.updates_to_ldap_options[:if].should == []
    p.ldap_apply_conditions.should == true
  end

  it "should be able to tell if the ldap entry exists" do
    p = Person.new :first_name => "Fred", :last_name => "Jones"
    p.ldap_exists?.should == false
    p.save
    p.ldap_exists?.should == true
  end

  it "should switch to update if creating an ldap entry that already exists" do
    p = Person.new :first_name => "Existing", :last_name => "Person", :email => "newaddress@local"
    p.ldap_exists?.should == true
    p.get_ldap_hash[:mail].should == ["existingperson@local"]
    p.save
    p.get_ldap_hash[:mail].should == ["newaddress@local"]
  end

  it "should create an ldap entry when creating a new person" do
    Person.ldap_connection.open do |ldap|
      result = ldap.search :filter => "cn=Fred Jones",
                           :scope => Net::LDAP::SearchScope_WholeSubtree
      result.size.should == 0
      p = Person.create :first_name => "Fred", :last_name => "Jones"
      p.dn.should == "cn=Fred Jones,ou=People"
      result = ldap.search :filter => "cn=Fred Jones",
                           :scope => Net::LDAP::SearchScope_WholeSubtree
      ldap.get_operation_result.code.should == 0
      result.size.should == 1
    end
  end

  it "should be able to switch to a more detailed objectclass when updating" do
    p = Person.new :first_name => "Fred", :last_name => "Jones", :email => "fredjones@gmail.com"
    p.use_person_for_objectclass = true
    p.save
    p.ldap_exists?.should == true
    p.get_ldap_hash[:mail].should == []
    p.use_person_for_objectclass = false
    p.save
    p.get_ldap_hash[:mail].should == ["fredjones@gmail.com"]
  end

  it "should be able to switch to a less detailed objectclass when updating" do
    p = Person.new :first_name => "Fred", :last_name => "Jones", :email => "fredjones@gmail.com"
    p.use_person_for_objectclass = false
    p.save
    p.ldap_exists?.should == true
    p.get_ldap_hash[:mail].should == ["fredjones@gmail.com"]
    p.use_person_for_objectclass = true
    p.save
    p.get_ldap_hash[:mail].should == []
  end

  it "should not throw and error if deleting an ldap entry that does not exist" do
    p = Person.create :first_name => "Fred", :last_name => "Jones"
    p.ldap_exists?.should == true
    p.ldap_destroy
    p.ldap_exists?.should == false
    lambda {p.destroy}.should_not raise_exception
  end

  it "should switch to create if updating an ldap entry that does not exist" do
    p = Person.create :first_name => "Fred", :last_name => "Jones"
    p.ldap_exists?.should == true
    p.ldap_destroy
    p.ldap_exists?.should == false
    p.email = "fredjones@gmail.com"
    p.save
    p.ldap_exists?.should == true
    p.get_ldap_hash[:mail].should == ["fredjones@gmail.com"]
  end

  it "should update an ldap entry when updating a person" do
    Person.ldap_connection.open do |ldap|
      p = Person.create :first_name => "Fred", :last_name => "Jones", :email => "fred@gmail.com"
      p.email = "fred@cmu.ca"
      p.save
      result = ldap.search :filter => "cn=Fred Jones",
                           :scope => Net::LDAP::SearchScope_WholeSubtree
      result[0].mail.should == ["fred@cmu.ca"]
    end
  end

  it "should delete an attribute if missing on update" do
    Person.ldap_connection.open do |ldap|
      p = Person.create :first_name => "Fred", :last_name => "Jones", :email => "fred@gmail.com"
      result = ldap.search :filter => "cn=Fred Jones",
                           :scope => Net::LDAP::SearchScope_WholeSubtree
      result[0].attribute_names.should include(:mail)
      p.email = nil
      p.save
      result = ldap.search :filter => "cn=Fred Jones",
                           :scope => Net::LDAP::SearchScope_WholeSubtree
      result[0].attribute_names.should_not include(:mail)
    end
  end

  it "should delete records that are deleted" do
    Person.ldap_connection.open do |ldap|
      p = Person.create :first_name => "Fred", :last_name => "Jones", :email => "fred@gmail.com"
      result = ldap.search :filter => "cn=Fred Jones",
                           :scope => Net::LDAP::SearchScope_WholeSubtree
      result.size.should == 1
      p.destroy
      result = ldap.search :filter => "cn=Fred Jones",
                           :scope => Net::LDAP::SearchScope_WholeSubtree
      result.size.should == 0
    end
  end

  it "should set and retrieve the ldap_password" do
    Person.ldap_connection.open do |ldap|
      p = Person.create :first_name => "Fred", :last_name => "Jones", :email => "fred@gmail.com"
      p.ldap_password = "new password"
      result = ldap.search :filter => "cn=Fred Jones",
                           :scope => Net::LDAP::SearchScope_WholeSubtree,
                           :attributes => [:userPassword]
      result[0].userPassword[0].should == "new password"
      p.ldap_password.should == "new password"
    end
  end

  it "should authenticate with the correct password" do
    Person.ldap_connection.open do |ldap|
      p = Person.create :first_name => "Fred", :last_name => "Jones", :email => "fred@gmail.com"
      p.ldap_password = "new password"
      p.authenticate("new password").should be_true
    end
  end

  it "should fail to authenticate with the wrong password" do
    Person.ldap_connection.open do |ldap|
      p = Person.create :first_name => "Fred", :last_name => "Jones", :email => "fred@gmail.com"
      p.ldap_password = "new password"
      p.authenticate("wrong password").should_not be_true
    end
  end
end
