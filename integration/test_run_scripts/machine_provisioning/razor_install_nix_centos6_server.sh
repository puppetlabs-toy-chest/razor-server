#!/bin/bash
SCRIPT_PATH=$(pwd)
BASENAME_CMD="basename ${SCRIPT_PATH}"
SCRIPT_BASE_PATH=`eval ${BASENAME_CMD}`
USER_INPUT_OS='false'

if [ $SCRIPT_BASE_PATH = "machine_provisioning" ]; then
  cd ../../
fi

# PE build:
export pe_dist_dir=http://neptune.puppetlabs.lan/3.8/ci-ready/

#Getting provisioned OS:
supported_provisioning_OS=('CENTOS6' 'CENTOS7' 'RHEL6' 'RHEL7' 'UBUNTU14' 'ESXI55' 'WINDOW2012R2')

#Export the PLATFORM ENV variable:
if [ $# -gt 0 ]; then
  for i in "${supported_provisioning_OS[@]}"
  do
    if [ $i = $1 ]; then
      export PLATFORM=$i
      USER_INPUT_OS='true'
      echo "export PLATFORM=$i"
    fi
  done
fi

#If user input unsupported OS:
if [ $USER_INPUT_OS = "false" ]; then
  USAGE_MSG=$(echo ${supported_provisioning_OS[*]} | sed 's/ /|/g')
  echo "USAGE razor_install.sh <$USAGE_MSG>"
  exit 1
fi

beaker \
  --config test_run_scripts/configs/razor_install_nix_centos6_server.cfg \
  --debug \
  --pre-suite pre-suite \
  --tests tests/machine_provisioning/nix_pe_broker \
  --keyfile ~/.ssh/id_rsa-acceptance \
  --load-path lib \
  --preserve-host onfail \
  --timeout 360
