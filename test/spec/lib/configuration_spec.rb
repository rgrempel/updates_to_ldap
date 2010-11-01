require_relative '../spec_helper'

describe :configuration do
  it "should read default values from config/updates_to_ldap.yml" do
    ActiveRecord::Base.ldap_spec[:host].should == "localhost"
    ActiveRecord::Base.ldap_spec[:auth][:username].should == "cn=admin,dc=directory_test,dc=local"
    ActiveRecord::Base.ldap_spec[:auth][:password].should == "testing"
    ActiveRecord::Base.ldap_spec[:base].should == "dc=directory_test,dc=local"
  end

  it "should pass default values to Person class" do
    Person.ldap_spec[:host].should == "localhost"
    Person.ldap_spec[:auth][:username].should == "cn=admin,dc=directory_test,dc=local"
    Person.ldap_spec[:auth][:password].should == "testing"
    Person.ldap_spec[:base].should == "dc=directory_test,dc=local"
  end

  it "should use custom values passed in CustomPerson class" do
    CustomPerson.ldap_spec[:host].should == "localhost"
    CustomPerson.ldap_spec[:auth][:username].should == "cn=admin,dc=directory_test,dc=local"
    CustomPerson.ldap_spec[:auth][:password].should == "wrong"
    CustomPerson.ldap_spec[:base].should == "dc=directory_test,dc=local"
  end
end
