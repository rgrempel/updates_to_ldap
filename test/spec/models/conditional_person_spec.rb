require_relative '../spec_helper'

describe ConditionalPerson do
  before(:each) do
    ConditionalPerson.delete_ldap_base
    ConditionalPerson.process_ldif Rails.root.join("spec","fixtures","root.ldif")
  end

  it "should not save to ldap without email" do
    p = ConditionalPerson.create :first_name => "Ryan", :last_name => "Rempel"
    p.ldap_exists?.should == false
  end

  it "should save to ldap with email" do
    p = ConditionalPerson.create :first_name => "Ryan", :last_name => "Rempel", :email => "rgrempel@gmail.com"
    p.ldap_exists?.should == true
  end

  it "should delete when updating email to be nil" do
    p = ConditionalPerson.create :first_name => "Ryan", :last_name => "Rempel", :email => "rgrempel@gmail.com"
    p.ldap_exists?.should == true
    p.email = nil
    p.save
    p.ldap_exists?.should == false
  end

  it "should create when updating email to not be nil" do
    p = ConditionalPerson.create :first_name => "Ryan", :last_name => "Rempel"
    p.ldap_exists?.should == false
    p.email = "rgrempel@gmail.com"
    p.save
    p.ldap_exists?.should == true
  end
end
