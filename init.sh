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
TAILSCALE_AUTH_KEY=${TAILSCALE_AUTH_KEY:-$1}
TAILSCALE_SERVER=${TAILSCALE_SERVER:-"https://controlplane.tailscale.com"}

# CA Certs
CERT_INFO_FILE_URL=${CERT_INFO_FILE_URL:-"$REPO_URL.spectr.yaml"}
CERT_INFO_FILE=$CHAOS_DIR/certs.yaml

# Extra packages to install
CHAOS_APT_EXTRA="ufw jq yq curl wget nano htop uuid net-tools dnsutils unzip gnupg tree cron"

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
	unzip -ou /tmp/chaos.zip -d /tmp/
	mv /tmp/chaotic-main /tmp/`basename $CHAOS_DIR`
	sudo mv --force /tmp/`basename $CHAOS_DIR` `dirname $CHAOS_DIR`
	rm /tmp/chaos.zip
}

setup_hec_script(){
    ### SPLUNK HEC HELPER ###
    sudo sed -i -e "s/SPLUNK_HOST/$SPLUNK_HOST/g"                   $CHAOS_DIR/scripts/log_hec.sh
    sudo sed -i -e "s/SPLUNK_TOKEN/$SPLUNK_TOKEN/g"                 $CHAOS_DIR/scripts/log_hec.sh
    sudo sed -i -e "s/SPLUNK_FALCO_INDEX/$SPLUNK_FALCO_INDEX/g"     $CHAOS_DIR/scripts/log_hec.sh
}

setup_x509_script(){
    ### SPLUNK HEC HELPER ###
    sudo sed -i -e "s;CHAOS_DIR;$CHAOS_DIR;g"                       $CHAOS_DIR/scripts/chaos-x509.sh
}

init_chaos() {
	# Setup chaos mgmt dirs
	# Check if directory exists
	if [ -d "$CHAOS_DIR" ]; then
		sudo rm -rf "$CHAOS_DIR"
	fi

	pull_chaos

	# Create the group if it doesn't exist
	if ! getent group "$CHAOS_GROUP" > /dev/null 2>&1; then
		echo "Creating group: $CHAOS_GROUP"
		sudo groupadd "$CHAOS_GROUP"
	fi

	# Add user to the chaos group
	sudo usermod -aG "$CHAOS_GROUP" "`whoami`"

	# Setup Cron
	sudo crontab -r || true
	(	
		echo "0 * * * * $CHAOS_DIR/scripts/cf-ip-update.sh | logger -t cf-ip-update";
		echo "0 * * * * $CHAOS_DIR/scripts/chaos-x509.sh   | logger -t chaos-x509"
	) | sudo crontab -

	# Setup HEC logger
	setup_hec_script

	# Set permissions on the chaos mgmt dirs
	sudo chown -R root:$CHAOS_GROUP $CHAOS_DIR
	sudo chmod -R 655 $CHAOS_DIR/{x509,scripts}

	# Add scripts dir to the path
	export PATH="$CHAOS_DIR/scripts:$PATH"
	echo "export PATH=$CHAOS_DIR/scripts:\$PATH" >> ~/.bashrc

	# Setup CAs
	setup_x509_script
	sudo $CHAOS_DIR/scripts/chaos-x509.sh
}

run() {
	# update_system_packages

	# echo "[ENTER] STEP 1"
	
	# # chaos
	init_chaos
	# echo "[ENTER] STEP 2 - CHAOS"

	# # Security
	# source $CHAOS_DIR/chaotic/sekurity.sh
	# sysctl_settings
	# install_scanning_tools
	# setup_syslog
	# echo "[ENTER] STEP 3 - sysctl"

	# # tailscale
	# setup_tailscale
	# echo "[ENTER] STEP 4 - Tailscale"

	# # kube
	# source $CHAOS_DIR/chaotic/k3s.sh
	# install_k3s
	# sudo systemctl status k3s
	# echo "[ENTER] STEP 4 - k3s"

	source $CHAOS_DIR/chaotic/gvisor.sh
	install_gvisor

	# Falco
	source $CHAOS_DIR/chaotic/falco.sh
	install_falco

	sudo systemctl list-units | grep falco
	echo "[ENTER] STEP 4 - falco"


	# UFW
	source $CHAOS_DIR/chaotic/ufw.sh
	enable_ufw

	dmesg
	echo "[ENTER] STEP 4 - ufw"

	get_k3s_kubeconfig
	sudo kubectl get no
	sudo kubectl get runtimeclass
}

run