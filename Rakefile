require 'rake'

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

    require 'sequel/extensions/migration'
    Sequel::Migrator.apply(Razor.database, "db/migrate")
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
    Razor.database.tables.each do |table|
      Razor.database.run("DROP TABLE #{table} CASCADE")
    end
  end

  desc "Reset the database"
  task :reset, [:env] => [:nuke, :migrate]
end

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

  desc "Run CLI specs"
  RSpec::Core::RakeTask.new(:cli => :reset_tests) do |t|
    t.pattern = 'spec/cli/**/*_spec.rb'
  end
end

desc "Open a preloaded irb session"
task :console do
  libdir = File::expand_path(File::join(File::dirname(__FILE__), "lib"))
  sh "irb -I #{libdir} -r razor/initialize -r razor"
end
