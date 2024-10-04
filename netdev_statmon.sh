#!/bin/bash

# This script collects network statistics for a list of network interfaces and monitors IRQ affinity changes for a specified duration.
# The collected logs are saved in a temporary directory with a timestamp and compressed into a tar file.
# The script takes 3 arguments: interval, duration, and title, followed by a list of network interfaces.
# Usage: ./netdev_statmon.sh interval duration title <list of net interfaces>

swd () { dirname $(readlink -f $(realpath ${BASH_SOURCE[0]})); }

usage() {
	echo "Usage: $0 interval duration title <list of net interfaces>"
	exit 1
}

interval=$1
duration=$2
title=$3

[ -z "$interval" ] && usage
[ -z "$duration" ] && usage
[ -z "$title" ] && usage

shift 3
[ -z "$1" ] && usage
interfaces=$@

# mktemp with date in the name
LOG_DIR=/tmp/$(basename $0)-$(hostname -s)-$title-${interfaces// /_}
[ -d $LOG_DIR ] && { echo "ERROR: $LOG_DIR already exists"; exit 1; }

mkdir -p $LOG_DIR

pcidevs=$(for i in $interfaces; do ethtool -i $i | grep bus-info | awk '{print $2}'; done)
pcidevs_pattern=$(echo $pcidevs | sed 's/ /|/g')

echo "Interfaces: $interfaces"
echo "PCI devices: $pcidevs"
echo "Logs will be saved in $LOG_DIR"

collect_logs() {
	local LOG_NAME=$1
	( set -x;
	netstat -s > $LOG_DIR/netstat-s.$LOG_NAME.log
	nstat > $LOG_DIR/nstat.$LOG_NAME.log
	cat /proc/interrupts > $LOG_DIR/proc-interrupts.$LOG_NAME.log )

	for i in $interfaces; do
		(set -x; ethtool -S $i > $LOG_DIR/$i.ethtool.S.$LOG_NAME.log; )
	done
}

echo "Collecting logs before"
echo "$(date +'%Y%m%d-%H:%M:%S')" > $LOG_DIR/tstamp.before.log

collect_logs before

echo "Monitor irq affinity chages for $duration seconds"
( set -x; $(swd)/irq_aff_mon.sh "$pcidevs_pattern" $interval $duration > $LOG_DIR/irq_aff_mon.log )

echo "Collecting logs before"
collect_logs after
echo "$(date +'%Y%m%d-%H:%M:%S')" > $LOG_DIR/tstamp.after.log

# compress logs
hostname=$(hostname -s)
tarballname=stats-$hostname-$(date +"%Y%m%d-%H%M%S").tgz
( set -x; tar -C $(dirname $LOG_DIR) -czf  $tarballname $(basename $LOG_DIR) )
echo "log tar file: $(pwd)/$tarballname"
