#! /usr/bin/env bash
set -eu

pidfile="/var/run/cassandra/cassandra.pid"
command="/etc/init.d/cassandra start"

# Proxy signals
function kill_app(){
    kill $(cat $pidfile)
    exit 0 # exit okay
}
trap "kill_app" SIGINT SIGTERM

# Launch daemon
$command
sleep 2

cassandra-cli -B -f /tmp/users.create_homestead_cache.casscli
cassandra-cli -B -f /tmp/users.create_homestead_provisioning.casscli
cqlsh -f /tmp/users.create_xdm.cqlsh 

# Loop while the pidfile and the process exist
while [ -f $pidfile ] && kill -0 $(cat $pidfile) ; do
    sleep 0.5
done
exit 1000 # exit unexpected
