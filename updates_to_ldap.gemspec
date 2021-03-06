Gem::Specification.new do |gem|
  gem.name    = 'updates_to_ldap'
  gem.version = '0.0.1'
  
  gem.summary = "mirrors Rails data to LDAP"
  gem.description = "Provides support for your ActiveRecord classes to save LDAP entries"
  
  gem.authors  = ['Ryan Rempel']
  gem.email    = 'rgrempel@gmail.com'
  gem.homepage = 'http://github.com/rgrempel/updates_to_ldap'
 
  gem.platform = Gem::Platform::RUBY

  gem.add_dependency 'net-ldap'
  gem.add_dependency 'ruby-hmac'
  gem.add_dependency 'rails', '>= 3'
  gem.add_dependency 'activemodel', '>= 3'

  gem.has_rdoc = true
  gem.rdoc_options.concat %W{--main README.rdoc -S -N}

  # list extra rdoc files
  gem.extra_rdoc_files = %W{
  } 

  # ensure the gem is built out of versioned files
  gem.files = Dir['{bin,lib,man}/**/*', 'README*', 'LICENSE*', 'init.rb'] & `git ls-files -z`.split("\0")
end

