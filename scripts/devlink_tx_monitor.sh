#!/bin/bash

set +x; set -e

SCRIPT_DIR=$(dirname "$(realpath "$0")")/..

[ -z "$1" ] && { echo "Please provide the output directory as an argument"; exit 1; }
[ -z "$2" ] && { echo "Please provide the interval as an argument"; exit 1; }
[ -z "$3" ] && { echo "Please provide the netdev as an argument"; exit 1; }

output_dir=$1
interval=$2

netdev=$3

while [ ! -d "/sys/class/net/$netdev" ]; do
	echo "Network device $netdev not found. Waiting..."
	sleep 5
done

pci_dev=$(ethtool -i $netdev | grep bus-info: | cut -d: -f2- | xargs)
[ -z "$pci_dev" ] && { echo "No PCI device found for $netdev"; exit 1; }
device=pci/$pci_dev

#netdev=$(ls -1 /sys/bus/pci/devices/$1/net)
#[ -z "$netdev" ] && { echo "No network device found for $device"; exit 1; }

aux_dev_file=$(find /sys/class/net/$netdev/device/ -type d -name "mlx5_core.eth.*")
if [ -n "$aux_dev_file" ]; then
	aux_dev=$(basename $aux_dev_file)
	tx_reporter_dev=$(devlink health | grep "$aux_dev/" | sed 's/:$//')
fi
[ -z "$tx_reporter_dev" ] && tx_reporter_dev=$(devlink health | grep "$device/" | sed 's/:$//')
[ -z "$tx_reporter_dev" ] && { echo "No tx reporter found for $device"; exit 1; }

[ -z "$output_dir" ] && output_dir=$(mktemp -d)
BASETMPDIR=$output_dir
output_dir=$(realpath "$output_dir")/devlink_tx_monitor-$(date +%Y-%m-%d-%H%M%S)
mkdir -p "$output_dir"
rm -rf $output_dir/*
log_file="$output_dir/monitor.log"
run_log="$output_dir/run.log"
# dobule click away from reading the dumps
echo "<a href=".">devlink_tx_monitor dumps HERE</a>" > $output_dir/index.html

cmd="devlink health diagnose $tx_reporter_dev reporter tx"

echo "Monitoring [$cmd] every $interval seconds\n\tDevice $device [$tx_reporter_dev] [$netdev] to $outd_dir" | tee -a "$log_file"

do_tx_health_diag() {
	local timestamp=$1
	[ -z "$timestamp" ] && timestamp=$(date +%Y-%m-%d-%H%M%S)
	local out_file="$output_dir/dump_$timestamp.txt"
	#echo "Running $cmd > $out_file"
	$cmd > "$out_file"
	echo "$out_file"
}

check_cq_state() {
	cat $1 | grep "cqn" | tee -a $log_file
	echo "Checking for CQ state in $1" | tee -a "$log_file"
	grep -q "ci is stuck" $1 && {
		grep "ci is stuck" $1
		echo "[X][X] Error: 'ci is stuck' found in $1. Stopping script." | tee -a "$log_file"
		pkill -P $$
		exit 1
	} || true

	grep -q "HW state: 10" "$1" && {
		grep "HW state: 10" $1
		echo "[X] Warning: 'HW state: 10' disarmed CQ found in $1" | tee -a "$log_file"
	} || true
}

on_terminate() {

	echo "Script terminated. Output directory: $output_dir" | tee -a "$run_log"
	(set -x; bash $SCRIPT_DIR/sysnetdump.sh $netdev $output_dir | tee -a "$run_log"; set +x)

	local ARCHIVE_DIRNAME=$(basename $output_dir)
	local ARCHIVE_NAME=$ARCHIVE_DIRNAME.tar.gz
	echo "Archiving $output_dir into $ARCHIVE_NAME"  | tee -a "$run_log"

	set -e
	(set -x; tar -C $BASETMPDIR -czf $BASETMPDIR/$ARCHIVE_NAME $ARCHIVE_DIRNAME )
	ls -lh1 $BASETMPDIR/$ARCHIVE_NAME
	echo "Arcive file: $BASETMPDIR/$ARCHIVE_NAME"
	exit
}

trap 'on_terminate' SIGINT SIGTERM EXIT

# TURN OFF auto recover
(set -x; devlink health set $tx_reporter_dev reporter tx auto_recover false | tee -a "$run_log"; set +x)
(set -x; bash $SCRIPT_DIR/sysnetdump.sh $netdev $output_dir | tee -a "$run_log"; set +x)


echo "Monitoring [$cmd] into $output_dir" | tee -a "$log_file"

while true; do
	timestamp=$(date +%Y-%m-%d-%H%M%S)
	out_file=$(do_tx_health_diag $timestamp)
	echo "$timestamp: Output saved to $out_file" | tee -a "$log_file"
	check_cq_state "$out_file"
	sleep $interval
done
