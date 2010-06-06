require File.expand_path('../../test_helper', __FILE__)

class ConnectionTest < ActiveSupport::TestCase
  context "The connection" do
    should "be bound with correct password" do
      assert_nothing_raised do
        Person.establish_ldap_connection :bind_dn => 'cn=admin,dc=directory_test,dc=local',
                                         :bind_pw => 'testing'
      end
      assert Person.ldap_connection.bound?, "Connection should be bound"
    end

    should "be bound by the initializer" do
      assert Person.ldap_connection.bound?, "should be bound by initializer"
    end
    
    should "not be bound with incorrect password" do
      assert_raise LDAP::ResultError do
        Person.establish_ldap_connection :bind_dn => 'cn=admin,dc=directory_test,dc=local',
                                         :bind_pw => 'testingwrong'
      end
    end
  end
end
