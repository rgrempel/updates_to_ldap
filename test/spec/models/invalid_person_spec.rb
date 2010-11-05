require_relative '../spec_helper'

describe InvalidPerson do
  before(:each) do
    InvalidPerson.delete_ldap_base
    InvalidPerson.process_ldif Rails.root.join("spec","fixtures","root.ldif")
  end

  it "should throw error when creating an invalid ldap entry" do
    lambda {InvalidPerson.create :first_name => "Fred", :last_name => "Jones"}.should raise_error(Net::LDAP::ServerError)
  end
end
