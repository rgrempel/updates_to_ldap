require 'rake'
require 'rake/testtask'

#
# Test tasks
#

desc 'Default: Run tests.'
task :default => :test

Rake::TestTask.new("test") do |t|
  t.test_files = FileList['test/*test.rb']
  t.verbose = true
end

