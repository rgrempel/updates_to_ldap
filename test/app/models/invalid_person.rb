class InvalidPerson < ActiveRecord::Base
  updates_to_ldap

  def full_name
    "#{first_name} #{last_name}"
  end

  def dn
    "cn=#{full_name},ou=People"
  end

  def to_ldap_hash
    {
      :cn => [full_name],
      :givenName => [first_name],
      :sn => [last_name],
      :mail => email.nil? ? [] : [email]
    }
  end
end
