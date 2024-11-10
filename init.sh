#!/bin/bash 

# Exit on any error
set -e

REPO_URL=https://github.com/MaxwellDPS/chaotic/archive/refs/heads/main.zip

# CHAOS SETTINGS
CHAOS_DOMAIN=${CHAOS_DOMAIN:-"chaos.corp"}
PUBLIC_DOMAIN=${PUBLIC_DOMAIN:-"virtuconindustries.net"}

CHAOS_GROUP=${CHAOS_GROUP:-"chaos"}
CHAOS_DIR=${CHAOS_DIR:-"/opt/chaos"}

# SPLUNK SETTINGS
SPLUNK_HOST=${SPLUNK_HOST:-"splunk.$CHAOS_DOMAIN"}
SPLUNK_PORT=${SPLUNK_PORT:-"6514"}
SPLUNK_TOKEN=${SPLUNK_TOKEN:-"POTATO"}
SPLUNK_FALCO_INDEX=${SPLUNK_FALCO_INDEX:-"falco"}

# Tailscale settings 
TAILSCALE_AUTH_KEY=${TAILSCALE_AUTH_KEY:-""}
TAILSCALE_SERVER=${TAILSCALE_SERVER:-"https://controlplane.tailscale.com"}

# CA Certs
CERT_INFO_FILE_URL=${CERT_INFO_FILE_URL:-"$REPO_URL.spectr.yaml"}
CERT_INFO_FILE=$CHAOS_DIR/certs.yaml

# Extra packages to install
CHAOS_APT_EXTRA="jq yq curl wget nano htop uuid net-tools dnsutils unzip gnupg tree cron"

# Minikube settings
POD_CIDR=${POD_CIDR:-"192.168.20.0/22"}
SVC_CIDR=${SVC_CIDR:-"192.168.26.0/22"}
KUBERNETES_VERSION=${KUBERNETES_VERSION:-"stable"}


update_system_packages() {
	sudo apt update
	sudo apt upgrade -y

	# Install some basiks
	sudo apt install -y \
		unattended-upgrades \
		apt-transport-https \
		ca-certificates \
		$CHAOS_APT_EXTRA

	# Enable automatic updates yo
	sudo dpkg-reconfigure --priority=low unattended-upgrades --frontend=noninteractive
}

setup_tailscale(){
	# Install and Up tailscale
	curl -fsSL https://tailscale.com/install.sh | sudo sh && \
	sudo tailscale up \
		--auth-key=$TAILSCALE_AUTH_KEY \
		--login-server=$TAILSCALE_SERVER
}


pull_chaos(){
	curl -sSL -o /tmp/chaos.zip $REPO_URL
	sudo mkdir -p $CHAOS_DIR
	unzip /tmp/chaos.zip -d /tmp/
	sudo mv /tmp/chaotic-main $CHAOS_DIR
	rm /tmp/chaos.zip
	source $CHAOS_DIR/chaotic/*.sh
}

init_chaos() {
	# Setup chaos mgmt dirs
	sudo mkdir -p $CHAOS_DIR
	pull_chaos

	# Create the group if it doesn't exist
	if ! getent group "$CHAOS_GROUP" > /dev/null 2>&1; then
		echo "Creating group: $CHAOS_GROUP"
		sudo groupadd "$CHAOS_GROUP"
	fi

	# Add user to the chaos group
	sudo usermod -aG "$CHAOS_GROUP" "`whoami`"
	# Activate the chaos group
	newgrp $CHAOS_GROUP

	# Pull helper scripts
	setup_chaos_script_cron
	sudo crontab -l

	# Setup HEC logger
	setup_hec_script

	cat $CHAOS_DIR/

	# Set permissions on the chaos mgmt dirs
	sudo chown -R root:$CHAOS_GROUP $CHAOS_DIR
	sudo chmod -R 660 $CHAOS_DIR/{x509,scripts}
	sudo chmod 664 $CHAOS_DIR/config

	# Add scripts dir to the path
	export PATH="$CHAOS_DIR/scripts:$PATH"
	echo "export PATH=$CHAOS_DIR/scripts:\$PATH" >> ~/.bashrc

	# Setup CAs
	sudo chaos-x509.sh
}

run() {
	# ubuntu
	update_system_packages

	echo "[ENTER] STEP 1"
	sleep 5

	# chaos
	init_chaos

	tree $CHAOS_DIR
	echo "[ENTER] STEP 2 - CHAOS"
	sleep 5

	# Security
	chaos_harden

	echo "[ENTER] STEP 3 - sysctl"
	sleep 5

	# tailscale
	setup_tailscale

	echo "[ENTER] STEP 4 - Tailscale"
	sleep 5

	# kube
	install_k3s

	sudo systemctl status k3s
	echo "[ENTER] STEP 4 - k3s"
	sleep 5


	# Falco
	install_falco

	sudo systemctl list-units | grep falco
	echo "[ENTER] STEP 4 - falco"
	sleep 5


	# UFW
	enable_ufw

	dmesg
	echo "[ENTER] STEP 4 - ufw"
	sleep 5

	get_k3s_kubeconfig
}

run