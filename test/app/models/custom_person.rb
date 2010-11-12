class CustomPerson < ActiveRecord::Base
  authenticates_to_ldap :ldap_spec => {
                          :auth => {
                            :username => "cn=admin,dc=directory_test,dc=local",
                            :method => :simple,
                            :password => "wrong"
                          }
                        }
end
