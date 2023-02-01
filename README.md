# sysdbugz
Handy linux debugging scripts

### sysnetdump.sh
Dumps system information related to networking and packs it into a tar file.

Usage:
```
curl -s https://raw.githubusercontent.com/saeedtx/sysdbugz/main/sysnetdump.sh | sudo bash -s <network interface name>
```

#### example OUTPUT:
```
curl -s https://raw.githubusercontent.com/saeedtx/sysdbugz/main/sysnetdump.sh | sudo bash -s mlx0
```
```
Dumping system information to /tmp/sysdump-8Ci-20230201063342
+ uname -a
+ lscpu
+ lspci -vvv
+ ifconfig -a
+ dmesg -T
+ modinfo mlx5_core
+ tail -n +1 /sys/module/mlx5_core/parameters/debug_mask /sys/module/mlx5_core/parameters/prof_sel
+ lspci -s 04:00.0 -vvv -xxxx
+ ethtool mlx0
+ ethtool -i mlx0
+ ethtool -k mlx0
+ ethtool -c mlx0
+ ethtool -g mlx0
+ ethtool -l mlx0
+ ethtool -x mlx0
+ ethtool -S mlx0
+ ethtool -a mlx0
+ ethtool -m mlx0
+ ethtool --show-priv-flags mlx0
+ ethtool -T mlx0
+ ethtool -u mlx0
+ ethtool --show-fec mlx0
+ ethtool --show-tunnels mlx0
+ devlink dev show
+ devlink dev info
+ devlink dev param
+ devlink port
+ devlink health
Archiving /tmp/sysdump-8Ci-20230201063342 into sysdump-8Ci-20230201063342.tar.gz
+ tar -C /tmp -czf sysdump-8Ci-20230201063342.tar.gz sysdump-8Ci-20230201063342
Dump was completed, please send sysdump-8Ci-20230201063342.tar.gz to the support team
/tmp/sysdump-8Ci-20230201063342.tar.gz
```

> Once done, send the output tar file to the dev/support team


#### Reviewing the logs

> Unpack the attached tar file and double click on index.html

##### OR
```
tar -xvf /tmp/sysdump-8Ci-20230201063342.tar.gz
your-favorite-web-browser sysdump-8Ci-20230201063342
```
