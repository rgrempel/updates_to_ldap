require_relative '../spec_helper'

describe :hash, :ldap_merge do
  it "should merge ldap hashes by concat'ing array values" do
    result = {
      :objectClass => ['inetOrgPerson'],
      :cn => ["Ryan Rempel"]
    }.ldap_merge({
      :objectClass => ['posixAccount'],
      :uid => ['ryan']
    })
    
    result.should == {
      :objectClass => ['inetOrgPerson', 'posixAccount'],
      :uid => ['ryan'],
      :cn => ["Ryan Rempel"]
    }
  end
end
