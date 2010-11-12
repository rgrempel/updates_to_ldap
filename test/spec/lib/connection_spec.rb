require_relative '../spec_helper'

describe :ldap_connection do
  it "should be bound with the correct password" do
    ldap = Person.ldap_connection
    assert ldap.bind, ldap.get_operation_result.inspect
  end

  it "should not be bound with the incorrect password" do
    ldap = CustomPerson.ldap_connection
    assert !ldap.bind, ldap.get_operation_result.inspect
  end

  it "should be able to load the root.ldif" do
    Person.delete_ldap_base
    Person.process_ldif Rails.root.join("spec", "fixtures", "root.ldif")
    ldap = Person.ldap_connection
    result = ldap.search :filter => "objectClass=*",
                         :scope => Net::LDAP::SearchScope_WholeSubtree
    puts ldap.get_operation_result.inspect unless result
    result.size.should == 3
  end

  it "should be able to delete the base dn" do
    Person.process_ldif Rails.root.join("spec", "fixtures", "root.ldif")
    Person.ldap_connection.open do |ldap|
      result = ldap.search(
        :base => Person.updates_to_ldap_options[:ldap_spec][:base],
        :scope => Net::LDAP::SearchScope_BaseObject,
        :filter => "objectclass=*",
        :return_result => true
      )
      ldap.get_operation_result.code.should == 0
      result.size.should == 1

      Person.delete_ldap_base
      result = ldap.search(
        :base => Person.updates_to_ldap_options[:ldap_spec][:base],
        :scope => Net::LDAP::SearchScope_BaseObject,
        :filter => "objectclass=*",
        :return_result => true
      )
      ldap.get_operation_result.code.should == 32 # 32 is object not found
    end
  end
end
