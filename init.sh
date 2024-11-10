#!/bin/bash 

# Exit on any error
set -e

REPO_URL=https://raw.githubusercontent.com/MaxwellDPS/chaotic/refs/heads/main/

# CHAOS SETTINGS
CHAOS_DOMAIN=${CHAOS_DOMAIN:-"chaos.corp"}
PUBLIC_DOMAIN=${PUBLIC_DOMAIN:-"virtuconindustries.net"}

CHAOS_GROUP=${CHAOS_GROUP:-"cchaos"}
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
CHAOS_APT_EXTRA=jq \
	yq \
	curl \
	wget \
	git \
	nano \
	htop \
	uuid \
	net-tools \
	dns-utils

# Minikube settings
POD_CIDR=${POD_CIDR:-"192.168.20.0/22"}
SVC_CIDR=${SVC_CIDR:-"192.168.26.0/22"}
KUBERNETES_VERSION=${KUBERNETES_VERSION:-"stable"}

source chaotic/*.sh

run() {
	# ubuntu
	update_system_packages

	# chaos
	init_chaos

	# Security
	harden_sysctl_settings
	install_scanning_tools
	setup_syslog

	# tailscale
	setup_tailscale

	# Rootless Docker
	install_rootless_docker

	# Falco
	install_falco

	# Minikube
	setup_minikube
	get_kubeconfig

	# UFW
	enable_ufw
}

run