#!/bin/sh

## Parameters:
# 1) Server version
# 2) Client version (optional, defaults to server version)
# 3) Repo conf URL (.repo file)

set -e # Exit on error
set -x # Verbose output

[  -n "${2}" ] && client_version=${2} || client_version=${1}
server_version=${1}
[ -n "$server_version" ] || (echo "Server version (1st parameter) required" && exit 1)
microkernel_version=007
[  -n "${3}" ] && repo_conf=${3} || repo_conf="http://builds.puppetlabs.lan/razor-server/${server_version}/repo_configs/rpm/pl-razor-server-${server_version}-el-6-x86_64.repo"

export razor_client_gem="http://builds.puppetlabs.lan/razor-client/${client_version}/artifacts/razor-client-${client_version}.gem"
export microkernel_url="http://links.puppetlabs.com/razor-microkernel-${microkernel_version}.tar"

echo " === Install repository === "
yum install -y wget
wget -O /etc/yum.repos.d/razor.repo $repo_conf
yum update -y --skip-broken
yum clean all
yum install -y razor-server

echo " === Install Postgresql ==="
yum install -y postgresql postgresql-server
postgresql-setup initdb
sed -i -r "s/  (peer|ident)/  trust/g" /var/lib/pgsql/data/pg_hba.conf
service postgresql start
sudo su - postgres <<HERE
psql -d postgres -c "create user razor with password 'razor';"
createdb -O razor razor_prd
HERE
service postgresql restart
psql -l -U razor razor_prd # Test that this connects.

echo " === Install Razor Server Packages ==="
yum update
yum install -y razor-server
source /etc/profile.d/razorserver.sh
sed -i "s/mypass/razor/g" /etc/puppetlabs/razor-server/config.yaml
razor-admin -e production migrate-database
service razor-server start
sleep 20
curl http://localhost:8150/api

echo " === Install razor-client ==="
cd ~
wget -O razor-client.gem $razor_client_gem
gem install ./razor-client.gem
# Only needed if testing a different port.
#export RAZOR_API="http://localhost:8150/api"
razor
echo " === Microkernel ==="
yum install -y wget
wget -O microkernel.tar $microkernel_url
tar -xvf microkernel.tar
mv microkernel /opt/puppetlabs/server/data/razor-server/repo
# razor create-repo --name microkernel --iso-url $microkernel_url --task noop
echo " === ISO Download and basic razor commands ==="
razor create-repo --name ubuntu-14 --iso-url http://contrib-test-vip.andrew.cmu.edu/pub/ubuntu-iso/CDs/14.04.1/ubuntu-14.04.1-server-amd64.iso --task ubuntu
razor create-broker --name noop --broker-type noop
razor create-policy --name ubuntu-14 --repo ubuntu-14 --task ubuntu --hostname node${id}.example.com --root-password password --broker noop
razor repos
razor brokers
razor policies
razor tasks

echo " === Basic hooks testing using 'counter' sample hook ==="
wget -O /usr/bin/jq http://stedolan.github.io/jq/download/linux64/jq
chmod +x /usr/bin/jq
razor register-node --hw-info net0=ab:ab:ab:ab --installed
razor create-hook --name counter --hook-type counter
razor run-hook --node node1 --name counter --event node-deleted
razor hooks counter configuration | grep -q "node-deleted: 1"

echo " === Smoke test completed successfully ==="