#!/usr/bin/bash +x
#
# SPDX-License-Identifier: GPL-2.0
# author: saeedm@nvidia.com
# date: 2019-05-08
# dump system information for debugging, Networking centric

NETIFACE=$1

[ -z $NETIFACE ] && { echo "Please specify the network interface" ; exit 1 ; }

# make tmp dir:
TMPDIR=$(mktemp -d /tmp/sysdump-XXX-$(date +%Y%m%d%H%M%S))
# run a command line and save output to file under $TMPDIR
dodump() {
	local FNAME=$1; shift
	echo "#$ $@" >> $TMPDIR/$FNAME
	(set -x; $@ &>> $TMPDIR/$FNAME)
}

echo "Dumping system information to $TMPDIR"

# generic
dodump uname "uname -a"
dodump lscpu "lscpu"
dodump lspci "lspci -vvv"
dodump "ifconfig" "ifconfig -a"
dodump "dmesg" "dmesg -T"

DRIVER_NAME=$(ethtool -i $NETIFACE | grep driver | awk '{print $2}')
dodump "modinfo" "modinfo $DRIVER_NAME"
dodump "module_params" "tail -n +1 /sys/module/$DRIVER_NAME/parameters/*"

PCIBUS=$(ethtool -i $NETIFACE | grep bus-info | awk '{print $2}' | cut -d: -f2-)
dodump "lspci-$NETIFACE" "lspci -s $PCIBUS -vvv -xxxx"

# ethtool
dodump_ethtool() { dodump "ethtool$1-$NETIFACE" "ethtool $1 $NETIFACE"; }

dodump_ethtool
ethtool_flags="-i -k -c -g -l -x -S -a -m --show-priv-flags -T -u --show-fec --show-tunnels"
for flag in $ethtool_flags; do dodump_ethtool $flag; done

# devlink
dodump_devlink() { 
	local name="$@";name="${name// /_}"
	dodump devlink-${name} devlink $@
}
dodump_devlink dev show
dodump_devlink dev info
dodump_devlink dev param
dodump_devlink port
dodump_devlink health

ARCHIVE_NAME=$(basename $TMPDIR)
BASETMPDIR=$(dirname $TMPDIR)

# dobule click away from reading the dumps
echo "<a href=".">$ARCHIVE_NAME</a>" > $TMPDIR/index.html

# we're done, archive time..
echo "Archiving $TMPDIR into $ARCHIVE_NAME.tar.gz"

set -e
(set -x; tar -C $BASETMPDIR -czf $ARCHIVE_NAME.tar.gz $ARCHIVE_NAME )

#list files in archive
#(set -x; tar -tzf $ARCHIVE_NAME.tar.gz)

rm -rf $TMPDIR

echo "Dump was completed, please send $ARCHIVE_NAME.tar.gz to the support team"
echo $(pwd)/$ARCHIVE_NAME.tar.gz 


# to view contents of the archive:
# tar -xvf $ARCHIVE_NAME.tar.gz
# your-favorite-web-browser $ARCHIVE_NAME
