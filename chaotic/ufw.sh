#!/bin/bash

config_ufw_defauts() {
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
	sudo ufw allow out to any port "$SPLUNK_PORT" proto tcp comment "Splunk syslog"

    ### k3s ###
    sudo ufw allow 6443/tcp #apiserver
    sudo ufw allow from $POD_CIDR to any #pods
    sudo ufw allow from $SVC_CIDR to any #services

}

config_ufw_defauts_lite() {
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
	sudo ufw allow out to any port "$SPLUNK_PORT" proto tcp comment "Splunk syslog"
}

enable_ufw_lite() {
	# Set default UFW policies
	sudo ufw default allow incoming
	sudo ufw default allow outgoing

	# Add Default policies
	config_ufw_defauts_lite
    
	# Enable UFW
	sudo ufw status | grep -qw "Status: active" || echo "y" | sudo ufw enable

	# Reload UFW to ensure changes take effect
	sudo ufw reload

    sudo ufw status
}

enable_ufw_lite_strict() {
	# Set default UFW policies
	sudo ufw default deny incoming
	sudo ufw default allow outgoing

	# Add Default policies
	config_ufw_defauts_lite
    
	# Enable UFW
	sudo ufw status | grep -qw "Status: active" || echo "y" | sudo ufw enable

	# Reload UFW to ensure changes take effect
	sudo ufw reload

    sudo ufw status
}


enable_ufw() {
	# Set default UFW policies
	sudo ufw default deny incoming
	sudo ufw default allow outgoing

	# Add Default policies
	config_ufw_defauts

    # Setup cloudflare IPs
	sudo $CHAOS_DIR/scripts/cf-ufw-rules.sh || true
    
	# Enable UFW
	sudo ufw status | grep -qw "Status: active" || echo "y" | sudo ufw enable

	# Reload UFW to ensure changes take effect
	sudo ufw reload

    sudo ufw status
}
