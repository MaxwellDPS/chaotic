#!/bin/bash

setup_chaos_scripts(){
	### Cloudflare IP Updates ###
	# Write the Cloudflare UFW Update script and adds to cron
	sudo curl -FsSL $REPO_URL/scripts/cf-ip-update.sh > $CHAOS_DIR/scripts/cf-ip-update.sh
	(sudo crontab -l 2>/dev/null; echo "0 * * * * $CHAOS_DIR/scripts/cf-ip-update.sh | logger -t cf-ip-update") | sudo crontab -

	### LUKS HELPER ###
	# Write the LUKS script
	sudo curl -FsSL $REPO_URL/scripts/add_luks_pw.sh > $CHAOS_DIR/scripts/add_luks_pw.sh

	### x509 HELPER ###
	# Write the x509 CA script
	sudo curl -FsSL $REPO_URL/scripts/install_chaos_ca.sh > $CHAOS_DIR/scripts/install_chaos_ca.sh
	(sudo crontab -l 2>/dev/null; echo "0 * * * * $CHAOS_DIR/scripts/install_chaos_ca.sh | logger -t install_chaos_ca") | sudo crontab -


	### SPLUNK HEC HELPER ###
	curl -FsSL $REPO_URL/scripts/log_hec.sh |\
    sed -e "s/SPLUNK_HOST/$SPLUNK_HOST/g" |\
    sed -e "s/SPLUNK_TOKEN/$SPLUNK_TOKEN/g" |\
    sed -e "s/SPLUNK_FALCO_INDEX/$SPLUNK_FALCO_INDEX/g" |\
    sudo tee $CHAOS_DIR/scripts/install_chaos_ca.sh
}

init_chaos() {
	# Install CLI utilities 4 when lazy
	sudo apt install -y $CHAOS_APT_EXTRA

	# Setup chaos mgmt dirs
	sudo mkdir -P $CHAOS_DIR
	sudo mkdir -P $CHAOS_DIR/{trust,scripts,config}

	# Download CA cert meta
	CERT_FILE=$CHAOS_DIR/certs.yaml
	curl -s $CERT_INFO_FILE_URL > $CERT_INFO_FILE

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
	setup_chaos_scripts

	# Set permissions on the chaos mgmt dirs
	sudo chown -R root:$CHAOS_GROUP $CHAOS_DIR
	sudo chmod -R 660 $CHAOS_DIR/{trust,scripts}
	sudo chmod 664 $CHAOS_DIR/config

	# Add scripts dir to the path
	export PATH="$CHAOS_DIR/scripts:$PATH"
	echo "export PATH=$CHAOS_DIR/scripts:\$PATH" >> ~/.bashrc
}