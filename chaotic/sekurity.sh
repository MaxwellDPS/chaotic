#!/bin/bash

install_scanning_tools() {
    # Install some sekurity
    sudo apt install -y \
        rkhunter \
        chkrootkit

    ### SCANNING ###
    # Add rootkit scan to cron
    (sudo crontab -l 2>/dev/null; echo "0 2 * * * /usr/sbin/rkhunter --check --rwo | logger -t rkhunter") | sudo crontab -
    (sudo crontab -l 2>/dev/null; echo "0 2 * * * /usr/sbin/chkrootkit | logger -t chkrootkit") | sudo crontab -
}

### SYSLOG ###
setup_syslog() {
  sudo apt install -y syslog-ng 

  # Configure syslog-ng to forward logs to Splunk
  curl -FsSL $REPO_URL/etc/syslog-ng/conf.d/splunk.conf |\
    sed -e "s/SPLUNK_HOST/$SPLUNK_HOST/g" |\
    sed -e "s/SPLUNK_PORT/$SPLUNK_PORT/g" |\
    sudo tee /etc/syslog-ng/conf.d/splunk.conf

  # Restart syslog-ng to apply changes
  sudo systemctl restart syslog-ng
  sudo systemctl enable syslog-ng
}

harden_sysctl_settings() {
	# harden sysctl settings
  sudo cp `pwd`/etc/sysctl.d/*.conf /etc/sysctl.d/
	sudo sysctl --system
}