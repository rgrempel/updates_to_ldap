require_relative '../spec_helper'

describe Person do
  before(:each) do
    Person.delete_ldap_base
    Person.process_ldif Rails.root.join("spec","fixtures","root.ldif")
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
