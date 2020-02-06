#!/bin/bash
script_dir=${0%/*}
acceptance_dir=$script_dir/../

cd $acceptance_dir

export pe_dist_dir=https://artifactory.delivery.puppetlabs.net/artifactory/generic_enterprise__local/2018.1/ci-ready

export BEAKER_TESTSUITE="${2:-suites/tests/}"
export BEAKER_PRESUITE="suites/pre_suite/install-server-from-package"
export BEAKER_CONFIG="$script_dir/hosts.cfg"
export BEAKER_KEYFILE="~/.ssh/id_rsa-acceptance"

export GENCONFIG_LAYOUT="${1:-redhat6-64mdca-64a}"

export GEM_SOURCE=https://artifactory.delivery.puppetlabs.net/artifactory/api/gems/rubygems/
bundle install --path vendor/bundle

bundle exec beaker-hostgenerator $GENCONFIG_LAYOUT > $BEAKER_CONFIG

: ${PE_RAZOR_SERVER_PACKAGE_BUILD_VERSION:?"PE_RAZOR_SERVER_PACKAGE_BUILD_VERSION is required"}

bundle exec beaker \
  --config $BEAKER_CONFIG \
  --pre-suite $BEAKER_PRESUITE \
  --tests $BEAKER_TESTSUITE \
  --keyfile $BEAKER_KEYFILE \
  --helper lib/helper.rb \
  --load-path lib \
  --type pe \
  --preserve-hosts onfail \
  --debug \
  --timeout 360
