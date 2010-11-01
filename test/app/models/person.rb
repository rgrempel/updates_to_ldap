class Person < ActiveRecord::Base
  authenticates_to_ldap
end
