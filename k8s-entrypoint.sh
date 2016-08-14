#!/bin/bash
set -x
set -e

if [ -z "$POD_IP" ]; then
  echo "Specify POD_IP in the env."
  exit 1
fi

if [ -z "$SCYLLA_SEEDS" ]; then
  echo "Specify SCYLLA_SEEDS in the env."
  exit 1
fi

if [ -z "$SCYLLA_CLUSTER_NAME" ]; then
  echo "Specify SCYLLA_CLUSTER_NAME in the env"
  exit 1
fi

sed -i -e "s/Test Cluster/$SCYLLA_CLUSTER_NAME/g" /etc/scylla/scylla.yaml
if [ -n "$SCYLLA_DC" ]; then
    echo "dc=$SCYLLA_DC" >> /etc/scylla/cassandra-rackdc.properties
fi
if [ -n "$SCYLLA_RACK" ]; then
    echo "rack=$SCYLLA_RACK" >> /etc/scylla/cassandra-rackdc.properties
fi

. /etc/default/scylla-server

CPUSET=""
if [ x"$SCYLLA_CPU_SET" != "x" ]; then
	CPUSET="--cpuset $SCYLLA_CPU_SET"
fi

if [ "$SCYLLA_PRODUCTION" == "true" ]; then
	DEV_MODE=""
	if [ ! -f /var/lib/scylla/.io_setup_done ]; then
    OLD_DEVMODE=$(cat /etc/scylla.d/dev-mode.conf)
    echo "DEV_MODE=--developer-mode=1" > /etc/scylla.d/dev-mode.conf
    /usr/lib/scylla/scylla_io_setup
    touch /var/lib/scylla/.io_setup_done
    echo ${OLD_DEVMODE} > /etc/scylla.d/dev_mode.conf
	fi
	# source /var/lib/scylla/io.conf
else
	DEV_MODE="--developer-mode true"
fi

if [ x"$SCYLLA_SEEDS" != "x" ];then
  SEEDS=$(getent hosts $SCYLLA_SEEDS | awk '{ print $1 }')
else
	SEEDS="$POD_IP"
fi

sed -i "s/seeds: \"127.0.0.1\"/seeds: \"$SEEDS\"/g" /etc/scylla/scylla.yaml
sed -i "s/listen_address: localhost/listen_address: $POD_IP/g" /etc/scylla/scylla.yaml
sed -i "s/.*broadcast_address:.*/broadcast_address: $POD_IP/g" /etc/scylla/scylla.yaml

# SET_USER="-u scylla"

chown -R scylla:scylla /var/lib/scylla
ln -fs /etc/scylla /var/lib/scylla/conf
sudo $SET_USER /usr/bin/scylla --developer-mode true --log-to-syslog 1 --log-to-stdout 0 $DEV_MODE $SEASTAR_IO $CPU_SET --default-log-level info --options-file /etc/scylla/scylla.yaml --listen-address $POD_IP --rpc-address $POD_IP --network-stack posix &

source /etc/default/scylla-jmx
export SCYLLA_HOME SCYLLA_CONF
exec sudo $SET_USER /usr/lib/scylla/jmx/scylla-jmx -l /usr/lib/scylla/jmx
