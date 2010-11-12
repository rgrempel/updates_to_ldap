class Person < ActiveRecord::Base
  updates_to_ldap

  attr_accessor :use_person_for_objectclass

  def full_name
    "#{first_name} #{last_name}"
  end

  def dn
    "cn=#{full_name},ou=People"
  end

  def to_ldap_hash
    retval = {
      :objectClass => [self.use_person_for_objectclass ? 'person' : 'inetOrgPerson'],
      :cn => [full_name],
      :sn => [last_name],
    }
    if self.use_person_for_objectclass
      retval.merge!({
        :givenName => [],
        :mail => []
      })
    else
      retval.merge!({
        :givenName => [first_name],
        :mail => email.nil? ? [] : [email]
      })
    end
    retval
  end
end
