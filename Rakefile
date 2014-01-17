require 'rake'
require 'torquebox-rake-support'

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
    # @todo lutter 2014-01-16: figure out a more sustainable way to
    # clean out the database
    Razor.database.run("DROP TYPE power_state")
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

desc "Build an archive"
task :archive do
  unless ENV["VERSION"]
    puts "Specify the version for the archive with VERSION="
    exit 1
  end
  topdir = Pathname.new(File::expand_path(File::dirname(__FILE__)))
  pkgdir = topdir + "pkg"
  pkgdir.mkpath
  full_archive = "razor-server-#{ENV["VERSION"]}-full.knob"
  Dir.mktmpdir("razor-server-archive") do |tmp|
    puts "Cloning into #{tmp}"
    system("git clone -q #{topdir} #{tmp}")
    puts "Create archive #{full_archive}"
    TorqueBox::DeployUtils.create_archive(
      name: full_archive,
      app_dir: tmp,
      dest_dir: pkgdir.to_s,
      package_without: %w[development test doc],
      package_gems: true)
  end
end
