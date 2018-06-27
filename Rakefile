require 'rake'
require 'pathname'
load './acceptance/tasks/acceptance.rake'
RAKE_ROOT = File.expand_path(File.dirname(__FILE__))

begin
  require 'torquebox-rake-support'
rescue LoadError
  STDERR.puts "Unable to load 'torquebox-rake-support'. Some rake tasks may be unavailable without this library."
end

task :default do
  system("rake -T")
end

namespace :bundler do
  task :setup do
    require 'bundler/setup'
  end
end

task :environment, [:env] => 'bundler:setup' do |cmd, args|
  ENV["RACK_ENV"] = args[:env] || "development"
  require_relative "./lib/razor/initialize"
end

namespace :db do
  desc "Run database migrations"
  task :migrate, :env do |cmd, args|
    env = args[:env] || "development"
    Rake::Task['environment'].invoke(env)

    sh "./bin/razor-admin -e #{env} migrate-database"
  end

  desc "Rollback the database"
  task :rollback, :env do |cmd, args|
    env = args[:env] || "development"
    Rake::Task['environment'].invoke(env)

    require 'sequel/extensions/migration'
    version = (row = Razor.database[:schema_info].first) ? row[:version] : nil
    Sequel::Migrator.apply(Razor.database, "db/migrate", version - 1)
  end

  desc "Nuke the database (drop all tables)"
  task :nuke, :env do |cmd, args|
    env = args[:env] || "development"
    Rake::Task['environment'].invoke(env)
    sh "./bin/razor-admin -e #{env} reset-database"
  end

  desc "Reset the database"
  task :reset, [:env] => [:nuke, :migrate]
end

if defined?(RSpec::Core::RakeTask)
  namespace :spec do
    require 'rspec/core'
    require 'rspec/core/rake_task'
  
    task :reset_tests do
      Rake::Task['db:reset'].invoke("test")
    end
  
    desc "Run all specs"
    RSpec::Core::RakeTask.new(:all => :reset_tests) do |t|
      t.pattern = 'spec/**/*_spec.rb'
    end
  end
end

desc "Open a preloaded irb session"
task :console do
  $: << File::expand_path(File::join(File::dirname(__FILE__), "lib"))

  require 'irb'
  require 'razor/initialize'
  require 'razor'

  puts "Model classes from Razor::Data have been included in the toplevel"
  include Razor::Data

  ARGV.clear
  IRB.start
end

begin
  spec = Gem::Specification.find_by_name 'gettext-setup'
  load "#{spec.gem_dir}/lib/tasks/gettext.rake"
  GettextSetup.initialize(File.absolute_path('locales', File.dirname(__FILE__)))
rescue LoadError
  # ignore
end
