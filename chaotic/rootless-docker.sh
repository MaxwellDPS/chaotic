#!/bin/bash

### APPARMOR ###
setup_apparmor() {
	sudo apt-get install -y uidmap apparmor apparmor-utils software-properties-common
	sudo systemctl enable apparmor
	sudo systemctl start apparmor
}

install_rootless_docker() {
	# Setup apparmor
	setup_apparmor

	# Install Docker dependencies
	sudo apt-get install -y iptables slirp4netns fuse-overlayfs

	# Install Docker for Rootless mode
	curl -fsSL https://get.docker.com/rootless | sh

	# Add Docker's binary path to your PATH
	export PATH=/home/$(whoami)/bin:$PATH
	echo 'export PATH=/home/$(whoami)/bin:$PATH' >> ~/.bashrc

	# Add self to docker group now
	sudo usermod -aG docker `whoami`
	newgrp docker

	# Ensure rootless install for app armor
	dockerd-rootless-setuptool.sh install
	docker context use rootless

	# Restart AppArmor to apply changes
	sudo systemctl restart apparmor

	# Verify AppArmor status
	sudo apparmor_status

	# Verify Docker installation
	~/.local/bin/dockerd-rootless-setuptool.sh check
}
