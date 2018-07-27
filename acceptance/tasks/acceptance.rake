require 'rake'

def generate_hosts(pe_version, test_target)
  hosts_file = 'hosts.cfg'
  pe_version = pe_version.gsub(/\.x$/, '')
  puts "Generating hosts..."
  cmd = <<HEREDOC
export BUNDLE_PATH=.bundle/gems
export BUNDLE_BIN=.bundle/bin

bundle install

beaker-hostgenerator --pe_dir=http://enterprise.delivery.puppetlabs.net/#{pe_version}/ci-ready \
--disable-default-role --hypervisor vmpooler #{test_target} > #{hosts_file}
HEREDOC

  Dir.chdir('acceptance'){
    system(cmd)
  }

  hosts_file
end

def run_beaker(hosts_file, tests, package_version)
cmd = <<HEREDOC
# We should change this to SHA and SUITE_VERSION in the acceptance tests
export PE_RAZOR_SERVER_PACKAGE_BUILD_VERSION=#{package_version}

bundle exec beaker --xml --debug --root-keys --repo-proxy --hosts #{hosts_file} \
--type pe --keyfile ~/.ssh/id_rsa-acceptance --preserve-hosts onfail \
--helper lib/helper.rb --pre-suite suites/pre_suite/install-server-from-module \
--tests #{tests} --load-path lib
HEREDOC

  Dir.chdir('acceptance'){
    system(cmd)
  }
end

namespace :acceptance do
  desc "Run acceptance tests"
  task :full, [:pe_version, :razor_server_version, :test_target] do |t, args|
    abort("Required argument: :pe_version") if args[:pe_version].nil?
    server_version = args[:razor_server_version] || `git rev-parse HEAD`
    tests = 'suites/tests/smoke,suites/tests/full'
    hosts = generate_hosts(args[:pe_version], args[:test_target])
    run_beaker(hosts, tests, server_version)
  end

  desc "Run smoke tests"
  task :smoke, [:pe_version, :razor_server_version, :test_target] do |t, args|
    abort("Required argument: :pe_version") if args[:pe_version].nil?
    server_version = args[:razor_server_version] || `git rev-parse HEAD`
    test_target = args[:test_target] || 'centos7-64mdc-64a'
    tests = 'suites/tests/smoke'
    hosts = generate_hosts(args[:pe_version], test_target)
    run_beaker(hosts, tests, server_version)
  end
end
