require "bundler"
Bundler.setup

require 'test/unit'
require 'active_record'
require 'active_record/fixtures'
require 'active_support/time'
require 'active_support/test_case'
require 'shoulda'

FIXTURES_PATH = File.join(File.dirname(__FILE__), 'fixtures')

Time.zone = 'Central Time (US & Canada)'

dep = defined?(ActiveSupport::Dependencies) ? ActiveSupport::Dependencies : ::Dependencies
dep.load_paths.unshift FIXTURES_PATH

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
    
ActiveRecord::Base.establish_connection(
  :adapter => 'sqlite3',
  :database => ':memory:'
)
    
ActiveRecord::Base.silence do
  ActiveRecord::Migration.verbose = false
  load File.join(FIXTURES_PATH, 'schema.rb')
end
    
class ActiveSupport::TestCase
  setup do
    Fixtures.create_fixtures(FIXTURES_PATH, ActiveRecord::Base.connection.tables)
  end

  teardown do
    Fixtures.reset_cache
  end
end
