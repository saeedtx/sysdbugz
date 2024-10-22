TARBALL_NAME := sysdbugz.tar.gz
TARBALL_DIR := $(CURDIR)
INSTALL_DIR = /usr/local/bin/sysmon/scripts
SERVICE_DIR = /etc/systemd/system
LOG_DIR = /var/log/sysmon

IFNAME:=
DEV:=

.PHONY: tarball
tarball:
	tar --exclude-vcs --exclude='*.tar.gz' -czf $(TARBALL_NAME) -C $(TARBALL_DIR)/.. $(notdir $(TARBALL_DIR))

install:
	# Create directories if they do not exist
	sudo mkdir -p $(INSTALL_DIR)
	sudo mkdir -p $(LOG_DIR)

	sudo install -m 644 scripts/sysnetdump.sh $(INSTALL_DIR)/
	sudo install -m 644 scripts/devlink_health_report.sh $(INSTALL_DIR)/
	sudo chmod -R +x $(INSTALL_DIR)/
	$(MAKE) -C sysmon install

# make tx_stcuk_mon IFNAME=eth2 DEV='pci/0000:08:00.0/65535/'
tx_stuck:
	$(MAKE) -C sysmon tx_stuck IFNAME="$(IFNAME)" DEV="$(DEV)"

uninstall:
	# Remove directories
	sudo rm -rf $(INSTALL_DIR)