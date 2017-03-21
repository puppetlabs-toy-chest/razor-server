require 'rake'
require 'yaml'

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

namespace :spec do
  begin
    require 'rspec/core'
    require 'rspec/core/rake_task'

    task :reset_tests do
      Rake::Task['db:reset'].invoke("test")
    end

    desc "Run all specs"
    RSpec::Core::RakeTask.new(:all => :reset_tests) do |t|
      t.pattern = 'spec/**/*_spec.rb'
    end
  rescue LoadError
    # ignore
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
  require 'torquebox-rake-support'

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


# Support for our internal packaging toolchain.  Most people outside of Puppet
# Labs will never actually need to deal with these.
begin
  load File.join(File.dirname(__FILE__), 'ext', 'packaging', 'packaging.rake')
rescue LoadError
end

begin
  @build_defaults ||= YAML.load_file('ext/build_defaults.yaml')
  @packaging_url  = @build_defaults['packaging_url']
  @packaging_repo = @build_defaults['packaging_repo']
rescue
  STDERR.puts "Unable to read the packaging repo info from ext/build_defaults.yaml"
end

namespace :package do
  desc "Bootstrap packaging automation, e.g. clone into packaging repo"
  task :bootstrap do
    if File.exist?("ext/#{@packaging_repo}")
      puts "It looks like you already have ext/#{@packaging_repo}. If you don't like it, blow it away with package:implode."
    else
      cd 'ext' do
        %x{git clone #{@packaging_url}}
      end
    end
  end

  desc "Remove all cloned packaging automation"
  task :implode do
    rm_rf "ext/#{@packaging_repo}"
  end

  desc "Prepare the tree for TroqueBox distribution"
  task :torquebox do
    # This defaults to the JRuby used on our internal builders, if present, and
    # then falls back to searching the path as it should.
    jruby = (["/usr/local/share/pl-jruby/bin"] + ENV['PATH'].split(':')).find do |path|
      File.executable?(File.join(path, 'jruby'))
    end or raise "unable to locate JRuby to run bundler!"

    jruby = File.join(jruby, 'jruby')

    begin
      rm_f "Gemfile.lock"
      sh "#{jruby} -S bundle install --clean --no-cache --path vendor/bundle --without 'development test doc'"
      rm_f ".bundle/install.log"
    rescue
      unless @tried_to_install_bundler
        # Maybe the executable isn't installed in the parent, try and get it now.
        sh "#{jruby} -S gem install bundler" rescue nil
        @tried_to_install_bundler = true
        retry
      end

      unless @retried and @retried > 9
        @retried = (@retried || 0) + 1
        puts "gonna just retry that there bundle install against network errors"
        retry
      end

      raise
    end
  end
end

begin
  spec = Gem::Specification.find_by_name 'gettext-setup'
  load "#{spec.gem_dir}/lib/tasks/gettext.rake"
  GettextSetup.initialize(File.absolute_path('locales', File.dirname(__FILE__)))
rescue LoadError
  # ignore
end
