source "https://rubygems.org"

gem 'sinatra'
gem 'pg'
gem 'sequel'
# Because we are monkey-patching the queue_classic code, we depend on the
# exact version.  This should go away, along with the monkey patch, when
# upstream finishes resolving this ticket:
# https://github.com/ryandotsmith/queue_classic/issues/161
gem 'queue_classic', '= 2.1.4'

group :doc do
  gem 'yard'
  gem 'redcarpet'
  gem 'github-markup'
end

group :test do
  gem 'rack-test'
  gem 'rspec'
end

# This allows you to create `Gemfile.local` and have it loaded automatically;
# the purpose of this is to allow you to put additional development gems
# somewhere convenient without having to constantly mess with this file.
#
# Gemfile.local is in the .gitignore file; do not check one in!
eval(File.read(File.dirname(__FILE__) + '/Gemfile.local'), binding) rescue nil
