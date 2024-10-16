# Makefile for SysMon installation

INSTALL_DIR = /usr/local/bin/sysmon
SERVICE_DIR = /etc/systemd/system
LOG_DIR = /var/log/sysmon

# Sample logger script
SERVICE_FILE = sysmon@.service

MONITOR :=
INTERVAL :=
IFNAME :=
DEV :=

.PHONY: all install clean monitor

all: install

install: $(SERVICE_FILE)
	# Create directories if they do not exist
	sudo mkdir -p $(INSTALL_DIR)/scripts
	sudo mkdir -p $(SERVICE_DIR)
	sudo mkdir -p $(LOG_DIR)

	# Copy logger script
	sudo install -m 644 scripts/sysmon_log.sh $(INSTALL_DIR)/
	sudo cp ../scripts/*.sh $(INSTALL_DIR)/scripts/
	sudo chmod -R +x $(INSTALL_DIR)/

	# Copy service file
	sudo cp $(SERVICE_FILE) $(SERVICE_DIR)/
	sudo systemctl daemon-reload

	@echo "SysMon installation completed."
	@echo "You can now start the service with:"
	@echo "  sudo mkdir -p /etc/sysmon/ && sudo cp samples/sample1.sysmon.conf /etc/sysmon/"
	@echo "  sudo systemctl enable sysmon@sample1.service"
	@echo "  sudo systemctl start sysmon@sample1.service"
	@echo "  sudo systemctl status sysmon@sample1.service"
	@echo "  journalctl -u sysmon@sample1.service -b"
	@echo "  make monitor MONITOR=ethtool-S-eth2 INTERVAL=5 CMD=\"ethtool -S eth2\""

sample:
	sudo mkdir -p /etc/sysmon/
	sudo cp samples/sample1.sysmon.conf /etc/sysmon/
	sudo systemctl enable sysmon@sample1.service
	sudo systemctl restart sysmon@sample1.service

monitor:
	@echo "Installing serivce MONITOR=$(MONITOR) INTERVAL=$(INTERVAL) CMD=$(CMD) into /etc/sysmon/$(MONITOR).sysmon.conf"

	@if [ -z "$(MONITOR)" ]; then echo "MONITOR is not set"; exit 1; fi
	@if [ -z "$(INTERVAL)" ]; then echo "INTERVAL is not set"; exit 1; fi

	sudo mkdir -p /etc/sysmon/
	echo "SYSMON_CMD=\"$(CMD)\"" | sudo tee /etc/sysmon/$(MONITOR).sysmon.conf
	echo "SYSMON_INTERVAL=$(INTERVAL)" | sudo tee -a /etc/sysmon/$(MONITOR).sysmon.conf
	echo "SYSMON_NAME=$(MONITOR)" | sudo tee -a /etc/sysmon/$(MONITOR).sysmon.conf
	sudo systemctl enable sysmon@$(MONITOR).service
	sudo systemctl start sysmon@$(MONITOR).service
	sudo systemctl status sysmon@$(MONITOR).service
	@echo "journalctl -u sysmon@$(MONITOR).service -b"

tx_stuck:
	@echo "Installing tx_stuck service IFNAME=$(IFNAME) DEV=$(DEV) into /etc/sysmon/tx_stuck.sysmon.conf"

	@if [ -z "$(IFNAME)" ]; then echo "IFNAME is not set"; exit 1; fi
	@if [ -z "$(DEV)" ]; then echo "DEV is not set"; exit 1; fi

	sudo mkdir -p $(INSTALL_DIR)/scripts/
	sudo cp ../scripts/*.sh $(INSTALL_DIR)/scripts/
	sudo mkdir -p /etc/sysmon/
	sed "s/{{INTERFACE_NAME}}/$(IFNAME)/" samples/tx_stuck.sysmon.conf | sudo tee /etc/sysmon/tx_stuck.sysmon.conf
	sudo sed -i "s#{{HEALTH_REPORTER_DEV}}#$(DEV)#" /etc/sysmon/tx_stuck.sysmon.conf

	sudo systemctl enable sysmon@tx_stuck.service
	sudo systemctl start sysmon@tx_stuck.service
	sudo systemctl status sysmon@tx_stuck.service
	@echo "sudo systemctl status sysmon@tx_stuck.service"
	@echo "journalctl -u sysmon@tx_stuck.service -f"

stop:
	sudo systemctl stop sysmon@$(MONITOR).service
	sudo systemctl disable sysmon@$(MONITOR).service

stop_all:
	find /etc/sysmon/ -name "*.sysmon.conf" -exec basename {} \; | xargs -I {} sudo systemctl stop sysmon@{}.service
	find /etc/sysmon/ -name "*.sysmon.conf" -exec basename {} \; | xargs -I {} sudo systemctl disable sysmon@{}.service

list:
	find /etc/sysmon/ -name "*.sysmon.conf" -exec basename {} \;
	find /etc/systemd/system/ -name "sysmon*.service" -exec basename {} \;

clean:
	# Remove all service files with the specified prefix
	sudo find $(SERVICE_DIR) -name "sysmon*.service" -exec rm -f {} \;
	# Remove all logger scripts with the specified prefix
	sudo rm -rf $(INSTALL_DIR)
	# Remove log directories and their contents
	sudo rm -rf $(LOG_DIR)/*
	# Reload systemd to apply changes
	sudo systemctl daemon-reload
	@echo "Cleaned up service files, scripts, and logs for prefix: $(SERVICE_PREFIX)."