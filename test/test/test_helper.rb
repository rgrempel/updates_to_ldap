ENV["RAILS_ENV"] = "test"
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'
require 'shoulda'

class ActiveSupport::TestCase
  # Setup all fixtures in test/fixtures/*.(yml|csv) for all tests in alphabetical order.
  #
  # Note: You'll currently still have to declare fixtures explicitly in integration tests
  # -- they do not yet inherit this setting
  fixtures :all

  setup do
    begin
      Person.delete_ldap_root_dn
    end
    Dir[Rails.root.join "test", "fixtures", "*.ldif"].each do |ldif|
      Person.process_ldif ldif
    end
  end
end
