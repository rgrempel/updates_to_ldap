Gem::Specification.new do |gem|
  gem.name    = 'updates_to_ldap'
  gem.version = '0.0.1'
  gem.date    = Date.today.to_s
  
  gem.summary = "mirrors Rails data to LDAP"
  gem.description = "Provides support for your ActiveRecord classes to save LDAP entries"
  
  gem.authors  = ['Ryan Rempel']
  gem.email    = 'rgrempel@gmail.com'
  gem.homepage = 'http://github.com/rgrempel/updates_to_ldap'
  
  # ensure the gem is built out of versioned files
  gem.files = Dir['Rakefile', '{bin,lib,man,test,spec}/**/*',
                  'README*', 'LICENSE*'] & `git ls-files -z`.split("\0")
end

