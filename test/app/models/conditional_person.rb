class ConditionalPerson < Person
  set_table_name :people
  updates_to_ldap :if => :email

end
