#!/usr/bin/bash +x
#
# SPDX-License-Identifier: GPL-2.0
# author: saeedm@nvidia.com
# date: 2019-05-08
# dump system information for debugging, Networking centric

SCRIPT_DIR=$(dirname "$(realpath "$0")")

NETDEVS=()
PCI_DEV=""

extract_device() {
	local DEV=$1
	# check if DEV is netdev
	if ls /sys/class/net/$DEV > /dev/null 2>&1; then
		NETDEVS+=($DEV)
		PCI_DEV=$(basename $(realpath /sys/class/net/$DEV/device))
		[ ! -d /sys/bus/pci/devices/$PCI_DEV ] && PCI_DEV="" && return
	else
		PCI_DEV=$(ls -1 /sys/bus/pci/devices/ | grep $DEV)
		if [ $(echo "$PCI_DEVICE" | wc -l) -ne 1 ]; then
			echo "Please specify a unique PCI device" ; exit 1 ;
		fi
	fi
	[ -z $PCI_DEV ] && return
	# find all netdevs associated with the PCI device
	NETDEVS+=($(ls -1 /sys/class/net/ | grep -f <(ls -1 /sys/bus/pci/devices/$PCI_DEV/net/)))
}

[ -z $1 ] && { echo "Please specify a network interface/pci device" ; exit 1 ; }

extract_device $1

BASEDIR=$2
[ -z $BASEDIR ] && BASEDIR=/tmp/sysdump/
TMPDIR=$BASEDIR/sysdump-$(date +%Y-%m-%d-%H%M%S)

mkdir -p $TMPDIR
# run a command line and save output to file under $TMPDIR

DST_DIR=$TMPDIR
dodump() {
	local FNAME=$1; shift
	echo "#$ $*" >> "$DST_DIR/$FNAME"
	(set -x; eval "$*" &>> "$DST_DIR/$FNAME")
}

function system_dumps() {
	DST_DIR=$TMPDIR/system;	mkdir -p $DST_DIR

	echo "Dumping system information to $DST_DIR"

	# generic
	dodump uname "uname -a"
	dodump lscpu "lscpu"
	dodump lspci "lspci -vvv"
	dodump "ifconfig" "ifconfig -a"
	dodump "dmesg" "dmesg -T"
	dodump "journalctl-week" journalctl --since \'1 days ago\'
	dodump "journalctl-kernel" journalctl -k --since \'1 days ago\'
	dodump "ip-a" "ip a"
	dodump "ip-l" "ip l"
	dodump "ip-r" "ip r"
	dodump "ip-route" "ip route show"
	dodump "ip-neigh" "ip neigh show"
	dodump "tc-qdisc" "tc qdisc show"

	dodump sysctl-a "sysctl -a"
	dodump "lsmod" "lsmod"
	dodump "lsblk" "lsblk"
	dodump "df" "df -h"
	dodump "mount" "mount"
	dodump "ps" "ps aux"
	dodump "top" "top -b -n 1"
	dodump "free" "free -h"
	dodump "uptime" "uptime"
	dodump "lsof" "lsof"
	dodump "ss" "ss -tuln"
	dodump "netstat" "netstat -tuln"

	dodump "proc_interrupts" "cat /proc/interrupts"
	(set -x; cp -rf /proc/irq $DST_DIR/proc_irqs)
	(set -x; cp -rLf /proc/net $DST_DIR/proc_net > /dev/null 2>&1 )
	(set -x; cp -rf /proc/cmdline $DST_DIR/cmdline > /dev/null 2>&1 )
	(set -x; cp -rf /proc/meminfo $DST_DIR/meminfo > /dev/null 2>&1 )
	(set -x; cp -rf /proc/cpuinfo $DST_DIR/cpuinfo > /dev/null 2>&1 )
	(set -x; cp -rf /proc/version $DST_DIR/version > /dev/null 2>&1 )
	(set -x; cp -rf /proc/modules $DST_DIR/modules > /dev/null 2>&1 )
	(set -x; cp -rf /proc/iomem $DST_DIR/iomem > /dev/null 2>&1 )
	(set -x; cp -rf /proc/ioports $DST_DIR/ioports > /dev/null 2>&1 )
	(set -x; cp -rf /proc/kallsyms $DST_DIR/kallsyms > /dev/null 2>&1 )
	(set -x; cp -rf /proc/vmallocinfo $DST_DIR/vmallocinfo > /dev/null 2>&1 )
	(set -x; cp -rf /proc/vmstat $DST_DIR/vmstat > /dev/null 2>&1 )

	DST_DIR=$TMPDIR
}

dodump_devlink() {
	local name="$@";name="${name// /_}"
	dodump devlink-${name} devlink $@
}

function devlink_dumps() {
	dodump_devlink dev show
	dodump_devlink dev info
	dodump_devlink dev param
	dodump_devlink port
	dodump_devlink health
	dodump_devlink trap
}


# Wrapper function to execute devlink commands and generate output files
devlink_health_report() {
	local device=$1
	local reporter=$2
	local cmd=$3

	# Remove leading colon from the device name (if any)
	device=${device%:}

	# Generate file name based on device and reporter
	local base_filename="${DST_DIR}/devlink_${reporter}"
	local cmd_file=${cmd// /_}
	# Run devlink health show command
	local out_file="${base_filename}_${cmd_file}.txt"
	echo "Running 'devlink health show' for $device (reporter: $reporter)..."
	local cmd_exec="devlink health $cmd $device reporter $reporter"
	echo "commandline: $cmd_exec" > "$out_file"
	(set -x; $cmd_exec &>> "$out_file"; set +x)
}

devlink_health_dev() {
	local DEV=$1
	echo "Dumping devlink health information for $DEV"
	devlink health show | awk -v device="$DEV" '
	BEGIN {found = 0}
	/^[^ ]/ {found = ($1 == device)}
	found && /reporter/ {print $2}
	' | while read -r reporter; do
		DEV=${DEV%:}
		echo DEVICE=$DEV reporter=$reporter
		# Run the devlink health show command and save the output
		devlink_health_report $DEV $reporter show
		devlink_health_report $DEV $reporter diagnose
		devlink_health_report $DEV $reporter "dump show"
		(set -x; devlink health dump clear $DEV reporter $reporter; set +x)
	done
}

devlink_health_pci() {
	local PCI_DEV=$1
	[ -z "$PCI_DEV" ] && echo "Please specify the PCI device" && return
	# for each reporter
	PCI_DEV=pci/$PCI_DEV:
	echo "Dumping devlink health information for $PCI_DEV"
	devlink_health_dev $PCI_DEV
}

function pcidev_dumps() {
	local PCI_DEV=$1
	[ -z $PCI_DEV ] && return
	DST_DIR=$TMPDIR/pci-${PCI_DEV//:/_}; mkdir -p $DST_DIR

	dodump "lspci" "lspci -s $PCI_DEV -vvv -xxx"
	DRIVER_NAME=$(lspci -s 08:00.0 -vv | grep "driver in use:" | cut -d ":" -f2)
	dodump "modinfo" "modinfo $DRIVER_NAME"
	dodump "module_params" "tail -n +1 /sys/module/$DRIVER_NAME/parameters/*"
	(set -x; mkdir -p $DST_DIR/pci_dev; cp -rf /sys/bus/pci/devices/$PCI_DEV/* $DST_DIR/pci_dev/ > /dev/null 2>&1 )

	devlink_health_pci $PCI_DEV
	DST_DIR=$TMPDIR
}


devlink_health_netdev() {
	local NETDEV=$1
	local DEV=$(devlink port show | grep $NETDEV | awk '{print $1}')
	[ -z "$DEV" ] && echo "No devlink port found for $NETDEV" && return
	# for each reporter
	echo "Dumping devlink health information for $NETDEV ($DEV)"
	devlink_health_dev $DEV
}

dodump_ethtool() { dodump "ethtool$1-$2" "ethtool $1 $2"; }

function netdev_dumps() {
	local NETDEV=$1
	DST_DIR=$TMPDIR/netdev-$NETDEV; mkdir -p $DST_DIR

	DRIVER_NAME=$(ethtool -i $NETDEV | grep driver | awk '{print $2}')
	dodump "modinfo" "modinfo $DRIVER_NAME"
	dodump "module_params" "tail -n +1 /sys/module/$DRIVER_NAME/parameters/*"

	dodump "ip-addr" "ip addr show $NETDEV"
	dodump "ip-link" "ip link show $NETDEV"

	dodump_ethtool "" $NETDEV
	ethtool_flags="-i -k -c -g -l -x -S -a -m --show-priv-flags -T -u --show-fec --show-tunnels"
	for flag in $ethtool_flags; do dodump_ethtool $flag $NETDEV; done

	(set -x; cp -rf $(realpath /sys/class/net/$NETDEV) $DST_DIR/sys_class_net_$NETDEV > /dev/null 2>&1 )

	devlink_health_netdev $NETIFACE
	DST_DIR=$DST_DIR
}

system_dumps

devlink_dumps

pcidev_dumps $PCI_DEV

for NETIFACE in ${NETDEVS[@]}; do
	netdev_dumps $NETIFACE
done


#debugfs
mount -t debugfs none /sys/kernel/debug || true
if [ -d /sys/kernel/debug/mlx5/ ]; then
	(set -x; cp -rf /sys/kernel/debug/mlx5/ $TMPDIR/debugfs_mlx5 > /dev/null 2>&1 )
fi

# we're done, archive time..

ARCHIVE_NAME=$(basename $TMPDIR)
BASETMPDIR=$(dirname $TMPDIR)

# dobule click away from reading the dumps
echo "<a href=".">$ARCHIVE_NAME</a>" > $TMPDIR/clickme.html

echo "Archiving $TMPDIR into $ARCHIVE_NAME.tar.gz"

set -e
(set -x; tar -C $BASETMPDIR -czf $BASETMPDIR/$ARCHIVE_NAME.tar.gz $ARCHIVE_NAME )

#list files in archive
#(set -x; tar -tzf $ARCHIVE_NAME.tar.gz)

#rm -rf $TMPDIR

echo "Dump was completed, please send $ARCHIVE_NAME.tar.gz to the support team"
echo $BASETMPDIR/$ARCHIVE_NAME.tar.gz

# to view contents of the archive:
# tar -xvf $ARCHIVE_NAME.tar.gz
# your-favorite-web-browser $ARCHIVE_NAME
