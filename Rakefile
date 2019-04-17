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

namespace :docker do
  env = 'test'

  # Start a docker instance that hosts a Razor database in a `test` environment.
  # By default this adds user 'razor' and password 'razor', creating a database
  # named 'razor'. This can be used to run spec tests locally.
  desc "Start database container"
  task :db do
    printf "=> Starting database... "
    # Networking setup.
    system "docker network list | grep -q 'razor-db' || docker network create razor-db"
    # Creates a postgres container in Docker.
    if system("docker container list --all | grep -q razor-postgres")
      printf "Database already exists, starting... "
      system "docker start razor-postgres"
      puts "Database started"
    else
      printf "Running new database container... "
      system "docker run -d --network razor-db --expose 5432 --publish 5432:5432 --name razor-postgres -e POSTGRES_PASSWORD=razor -e POSTGRES_USER=razor -e POSTGRES_DB=razor postgres"
      puts "Started"
    end
    # Time for the docker container to settle.
    sleep 10
    Rake::Task['environment'].invoke
    Rake::Task['db:migrate'].invoke
  end

  desc "Stop docker container"
  task :db_stop do
    printf "=> Stopping database... "
    if system "docker ps | grep -q razor-postgres"
      system "(docker stop razor-postgres || true)"
      puts "Stopped"
    elsif system "docker container list --all | grep -q razor-postgres"
      puts "Already stopped"
    else
      puts "Does not exist"
    end
  end

  desc "Start torquebox container"
  task :tb do
    printf "=> Starting torquebox... "
    Rake::Task['docker:db'].invoke
    # Networking setup.
    system "docker network list | grep -q 'razor-db' || docker network create razor-db"
    # Build and run the image, using the tag `latest` and exposing ports 8150 and 8151.
    if system("docker ps | grep -q razor-server")
      # No-op
      puts "Torquebox already running"
    elsif system("docker container list --all | grep -q razor-server")
      # Box exists but is stopped, start it
      printf "Already exists, starting... "
      system "docker start razor-server"
      puts "Started"
    else
      # Box needs building and running.
      puts "Building torquebox image..."
      sh "docker build -t razor-torquebox #{File.dirname(__FILE__)}"

      puts "Running new torquebox container"
      # Run the instance. We need a few things:
      # Port 8080 forwarded for API and SVC traffic.
      # The `repo/` directory mounted, so the microkernel can live outside the container.
      # Connecting to an internal network, `razor-db`, which is where our postgres instance lives.
      sh "docker run --network razor-db -p 8150:8150 -d -v \"#{File.dirname(__FILE__)}/repo\":/var/lib/razor/repo-store -it --name razor-server razor-torquebox"
    end

    # To ensure the service is running, let's check the API.
    system <<-EOF
        url=http://localhost:8150/api
        printf "Waiting for API to be ready at ${url} "
        tries=0
        until $(curl --output /dev/null --silent --head --fail ${url}); do
          printf "."
          sleep 2
          tries=$((tries+1))
          if [ "$tries" -gt "400" ]; then
            echo; echo "Error: took too long to complete"; echo
            exit 1
          fi
        done
        echo "done!"
    EOF
  end

  desc "SSH inside the torquebox container"
  task :ssh do
    if system "docker ps | grep -q razor-server"
      sh "docker exec -it razor-server /bin/bash"
    else
      puts "Torquebox container not running!"
      exit 1
    end
  end

  desc "Stop the torquebox container"
  task :tb_stop do
    printf "=> Stopping torquebox..."
    system "(docker stop razor-server) || true"
    puts "Stopped"
  end

  desc "Start database and torquebox"
  task :start do
    Rake::Task["docker:db"].invoke
    Rake::Task["docker:tb"].invoke
  end

  desc "Stop database and torquebox"
  task :stop do
    Rake::Task["docker:tb_stop"].invoke
    Rake::Task["docker:db_stop"].invoke
  end

  desc "Restart database and torquebox"
  task :restart do
    Rake::Task["docker:stop"].invoke
    Rake::Task["docker:start"].invoke
  end

  # Great for wiping away an existing environment and starting fresh.
  desc "Reset database and torquebox"
  task :reset do
    Rake::Task["docker:stop"].invoke
    system("docker rm razor-server")
    system("docker rm razor-postgres")
    Rake::Task['docker:start'].invoke
  end

  desc "Clean up all docker-related containers, images, networks"
  task :clean do
    Rake::Task["docker:stop"].invoke
    system("docker rm razor-server")
    system("docker rmi razor-torquebox")
    system("docker rm razor-postgres")
    system("docker rmi jruby:9.1.5.0-alpine")
  end
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
