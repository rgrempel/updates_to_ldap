require File.expand_path('../../test_helper', __FILE__)

class ConnectionTest < ActiveSupport::TestCase
  context "The connection" do
    should "be bound with correct password" do
      assert_nothing_raised do
        ActiveRecord::Base.establish_ldap_connection :bind_dn => 'cn=admin,dc=directory_test,dc=local',
                                                     :bind_pw => 'testing'
      end
      assert Person.ldap_connection.bound?, "Connection should be bound"
    end

    should "be bound by the initializer" do
      assert Person.ldap_connection.bound?, "should be bound by initializer"
    end

    should "not be bound with incorrect password" do
      assert_raise LDAP::ResultError do
        ActiveRecord::Base.establish_ldap_connection :bind_dn => 'cn=admin,dc=directory_test,dc=local',
                                                     :bind_pw => 'testingwrong'
      end
      ActiveRecord::Base.establish_default_ldap_connection
    end

    should "have automatically loaded root.ldif" do
      assert_equal 1, Person.ldap_connection.search2(Person.ldap_spec[:root_dn], LDAP::LDAP_SCOPE_BASE, "objectclass=*").size, "Should have loaded the root_dn from ldif"  
    end

    should "be able to delete the root dn" do
      assert_equal 1, Person.ldap_connection.search2(Person.ldap_spec[:root_dn], LDAP::LDAP_SCOPE_BASE, "objectclass=*").size, "Should have loaded the root_dn from ldif"  
      Person.delete_ldap_root_dn
      assert_raise LDAP::ResultError do
        Person.ldap_connection.search2(Person.ldap_spec[:root_dn], LDAP::LDAP_SCOPE_BASE, "objectclass=*")
      end
      # We reload it because it will be automatically deleted
      Person.process_ldif Rails.root.join("test","fixtures","root.ldif")
    end
  end
end
