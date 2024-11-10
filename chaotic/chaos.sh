#!/bin/bash

setup_chaos_script_cron(){
	### Cloudflare IP Updates ###
	# Write the Cloudflare UFW Update script and adds to cron
	(sudo crontab -l 2>/dev/null; echo "0 * * * * $CHAOS_DIR/scripts/cf-ip-update.sh | logger -t cf-ip-update") | sudo crontab -

	### x509 HELPER ###
	# Write the x509 CA script
	(sudo crontab -l 2>/dev/null; echo "0 * * * * $CHAOS_DIR/scripts/chaos-x509.sh | logger -t chaos-x509") | sudo crontab -
}

setup_hec_script(){
    ### SPLUNK HEC HELPER ###
    sudo sed -i -e "s/SPLUNK_HOST/$SPLUNK_HOST/g"                   $CHAOS_DIR/scripts/log_hec.sh
    sudo sed -i -e "s/SPLUNK_TOKEN/$SPLUNK_TOKEN/g"                 $CHAOS_DIR/scripts/log_hec.sh
    sudo sed -i -e "s/SPLUNK_FALCO_INDEX/$SPLUNK_FALCO_INDEX/g"     $CHAOS_DIR/scripts/log_hec.sh
}

setup_x509_script(){
    ### SPLUNK HEC HELPER ###
    sudo sed -i -e "s/CHAOS_DIR/$CHAOS_DIR/g"                       $CHAOS_DIR/scripts/chaos-x509.sh
}