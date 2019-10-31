#!/bin/bash

## Parameters:
# 1) Server version
# 2) Client version (optional, defaults to server version)
# 3) Deb conf URL (.list file)

set -e # Exit on error
set -x # Verbose output

[  -n "${2}" ] && client_version=${2} || client_version=${1}
server_version=${1}
[ -n "$server_version" ] || (echo "Server version (1st parameter) required" && exit 1)
[  -n "${3}" ] && deb_conf=${3} || deb_conf="http://builds.puppetlabs.lan/razor-server/${server_version}/repo_configs/deb/pl-razor-server-${server_version}-xenial.list"

microkernel_version=007
export razor_client_gem="http://builds.puppetlabs.lan/razor-client/${client_version}/artifacts/razor-client-${client_version}.gem"
export microkernel_url="http://links.puppetlabs.com/razor-microkernel-${microkernel_version}.tar"

echo " === Install repository === "
wget -O /etc/apt/sources.list.d/razor.list $deb_conf
apt-get update

echo " === Install Postgresql ==="
sudo apt-get install -y postgresql postgresql-contrib
mkdir -p /var/lib/pgsql/data
chown postgres /var/lib/pgsql
chown postgres /var/lib/pgsql/data
sudo su - postgres <<HERE
/usr/lib/postgresql/9.5/bin/initdb -D /var/lib/pgsql/data/
sed -i -r "s/  (peer|ident)/  trust/g" /etc/postgresql/9.5/main/pg_hba.conf
service postgresql restart
psql -d postgres -c "create user razor with password 'razor';"
createdb -O razor razor_prd
HERE
service postgresql restart
psql -l -U razor razor_prd # Test that this connects.

echo " === Install Razor Server Packages ==="
apt-get update
apt-get -f install -y --force-yes razor-server
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
wget -O microkernel.tar $microkernel_url
tar -xvf microkernel.tar
mv microkernel /opt/puppetlabs/server/data/razor-server/repo
# Alternative:
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

echo " === Checking version ==="
razor -v

echo " === Smoke test completed successfully ==="