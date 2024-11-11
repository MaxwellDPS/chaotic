#!/bin/bash

config_ufw_defauts() {
	# Setup cloudflare IPs
	cf-ip-update.sh

	### Upgrades (4 now) ###
	# Allow outbound access for apt updates (HTTP and HTTPS)
	sudo ufw allow out 80/tcp  comment "[out] HTTP"
	sudo ufw allow out 443/tcp comment "[out] HTTPs"

	### DNS ###
	# Allow outbound access for 
	sudo ufw allow out 53/udp  comment "[out] DNS over UDP"
	sudo ufw allow out 53/tcp  comment "[out] DNS over TCP"
	sudo ufw allow out 853/tcp comment "[out] DNS over TLS"

	### SSH ###
	# Allow inbound access for SSH from CHAOS MGMT
	sudo ufw allow from 192.168.51.0/24 to any port 22 comment "CHAOS.CORP SSH"
	# Allow inbound access for SSH from TAILSCALE
	sudo ufw allow from 100.64.0.0/10 to any port 22 comment "TALESCALE SSH"

	### SYSLOG ###
	# Add firewall rule for syslog
	sudo ufw allow out to "$SPLUNK_HOST" port "$SPLUNK_PORT" proto tcp comment "Splunk syslog"

    ### k3s ###
    ufw allow 6443/tcp #apiserver
    ufw allow from $POD_CIDR to any #pods
    ufw allow from $SVC_CIDR to any #services

}

setup_ufw_for_docker() {
	# Enable UFW and set default policies
	
	# Set Docker rules for UFW
	sudo curl -sSL $REPO_URL/etc/ufw/after.rules -o /etc/ufw/after.rules

	# Configure Docker to stop manipulating iptables directly
	daemon_json="$XDG_CONFIG_HOME/docker/daemon.json"
	if [ ! -f "$daemon_json" ]; then
		echo "{}" > "$daemon_json"
	fi

	# Update daemon.json to prevent Docker from overriding iptables
	jq '. + {"iptables": false}' "$daemon_json" > tmp.json
	sudo mv tmp.json "$daemon_json"

	# Restart Docker and UFW to apply the changes
	systemctl --user restart docker ufw
}

enable_ufw() {
	# Set default UFW policies
	sudo ufw default deny incoming
	sudo ufw default allow outgoing

	# Fix UFW + Docker
	setup_ufw_for_docker

	# Add Default policies
	config_ufw_defauts

    # Cloudflare UFW rules
    cf-ufw-rules.sh
    
	# Enable UFW
	sudo ufw status | grep -qw "Status: active" || sudo ufw enable

	# Reload UFW to ensure changes take effect
	sudo ufw reload
}
