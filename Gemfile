source "https://rubygems.org"

gem 'sinatra'
gem 'pg'
gem 'sequel'

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
