#!/bin/bash

update_system_packages() {
	sudo apt update
	sudo apt upgrade -y

	# Install some basiks
	sudo apt install -y \
		unattended-upgrades \
		apt-transport-https \
		ca-certificates

	# Enable automatic updates yo
	sudo dpkg-reconfigure --priority=low unattended-upgrades
}