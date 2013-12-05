# Only using the SSL interface, please.
source 'https://rubygems.org'

# For the sake of RVM, this overrides the engine line below, which is too
# complicated for the simple shell parser to handle.  This ensures that RVM
# users get something at least vaguely sane out of the box.  (Which is really
# in the realm of 'developer courtesy settings', not production support.)
#
# If you prefer to override these choices with something more explicit, you
# can use the `.ruby-version` and `.ruby-gemset` files in your local checkout
# to take precedence over what is defined here.
#
# You should aim for jruby-1.7.4, since that is what is bundled into TorqueBox
# at the present time, so better to learn about bugs early, no?
#
# Note that the lack of whitespace matters in those two lines:
#ruby=jruby-1.7.8
#ruby-gemset=razor-server
ruby '1.9.3', :engine => 'jruby', :engine_version => '1.7.8'

gem 'torquebox', '~> 3.0.1'
gem 'sinatra'
gem 'sequel'
gem 'jdbc-postgres'
gem 'archive'
gem 'hashie', '~> 2.0.5'

## support for various installers and utility
# This allows us to encrypt plain-text-in-the-DB passwords when they travel,
# unencrypted, over the wire during kickstart phases, etc.
gem "unix-crypt", "~> 1.1.1"


group :doc do
  gem 'yard'
  gem 'kramdown'
end

# This group will be excluded by default in `torquebox archive`
group :test do
  gem 'rack-test'
  gem 'rspec', '~> 2.13.0'
  gem 'rspec-core', '~> 2.13.1'
  gem 'rspec-expectations', '~> 2.13.0'
  gem 'rspec-mocks', '~> 2.13.1'
  gem 'simplecov'
  gem 'fabrication', '~> 2.7.2'
  gem 'faker', '~> 1.2.0'
  gem 'json-schema', '~> 2.0'
  gem 'timecop'
end

# This group, also, will be excluded by default in `torquebox archive`
group :development do
  # The `torquebox-server` gem is only required for development: it brings in
  # the full TorqueBox stack, and is used to enable the `torquebox` command
  # for running a local dev instance stand-alone.
  #
  # For production you can use this, or deploy to a distinct installation of
  # TorqueBox, as you prefer.
  gem 'torquebox-server', '~> 3.0.1'
end

# This allows you to create `Gemfile.local` and have it loaded automatically;
# the purpose of this is to allow you to put additional development gems
# somewhere convenient without having to constantly mess with this file.
#
# Gemfile.local is in the .gitignore file; do not check one in!
eval(File.read(File.dirname(__FILE__) + '/Gemfile.local'), binding) rescue nil
