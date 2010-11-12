require_relative '../spec_helper'

describe :configuration do
  it "should read default values from config/updates_to_ldap.yml" do
    spec = Person.updates_to_ldap_options[:ldap_spec]
    spec[:host].should == "localhost"
    spec[:auth][:username].should == "cn=admin,dc=directory_test,dc=local"
    spec[:auth][:password].should == "testing"
    spec[:base].should == "dc=directory_test,dc=local"
  end

  it "should use custom values passed in CustomPerson class" do
    spec = CustomPerson.updates_to_ldap_options[:ldap_spec]
    spec[:host].should == "localhost"
    spec[:auth][:username].should == "cn=admin,dc=directory_test,dc=local"
    spec[:auth][:password].should == "wrong"
    spec[:base].should == "dc=directory_test,dc=local"
  end
end
