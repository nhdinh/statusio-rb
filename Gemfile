require 'rbconfig'

source 'https://rubygems.org'

gem 'rest-client'

group :test do
	gem 'rspec'
	gem 'webmock'
	gem 'vcr'
	gem 'turn'
	gem 'rake'
	gem 'win32console' if (RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/)
	gem 'ansi'
end

# Specify your gem's dependencies in statusio.gemspec
gemspec
