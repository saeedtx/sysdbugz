TARBALL_NAME := sysdbugz.tar.gz
TARBALL_DIR := $(CURDIR)

.PHONY: tarball
tarball:
	tar --exclude-vcs --exclude='*.tar.gz' -czf $(TARBALL_NAME) -C $(TARBALL_DIR)/.. $(notdir $(TARBALL_DIR))