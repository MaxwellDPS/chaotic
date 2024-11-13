#!/bin/bash

# Variables
SPLUNK_USER="splunk"
INSTALL_DIR="/opt/splunk"

DOMAIN_NAME=SPLUNK_HOST # Replace with your domain
CERT_PATH="/opt/chaos/ssl/splunk.crt"  # Replace with your certificate path
CERT_KEY_PATH="/opt/chaos/ssl/splunk.key"  # Replace with your private key path


download_splunk() {
    echo "Downloading Splunk..."
    wget -O /tmp/splunk-9.3.2-d8bb32809498-linux-2.6-amd64.deb https://download.splunk.com/products/splunk/releases/9.3.2/linux/splunk-9.3.2-d8bb32809498-linux-2.6-amd64.deb
    wget -O /tmp/splunk-9.3.2-d8bb32809498-linux-2.6-amd64.deb.sha512 https://download.splunk.com/products/splunk/releases/9.3.2/linux/splunk-9.3.2-d8bb32809498-linux-2.6-amd64.deb.sha512 
    sha512sum -c /tmp/splunk-9.3.2-d8bb32809498-linux-2.6-amd64.deb.sha512
    dpkg -i /tmp/splunk-9.3.2-d8bb32809498-linux-2.6-amd64.deb

}
start_splunk_service() {
    echo "Enabling Splunk service..."
    sudo -u $SPLUNK_USER $INSTALL_DIR/bin/splunk start --accept-license --answer-yes --no-prompt --seed-passwd SPLUNK_PASS
    $INSTALL_DIR/bin/splunk enable boot-start -user $SPLUNK_USER
}

# basic_hardening() {
#     echo "Applying basic hardening..."
#     sudo -u $SPLUNK_USER $INSTALL_DIR/bin/splunk set web-ssl enable
#     sudo -u $SPLUNK_USER $INSTALL_DIR/bin/splunk set minfreemb 500
#     sudo -u $SPLUNK_USER $INSTALL_DIR/bin/splunk set servername $DOMAIN_NAME
#     # Optional: Set up a custom admin password
# }

configure_nginx_proxy() {
		mkdir -p `dirname $CERT_KEY_PATH`

    openssl ecparam -genkey -name secp384r1 -out $CERT_KEY_PATH
    openssl req -new -x509 -days 420 \
        -key $CERT_KEY_PATH \
        -out $CERT_PATH \
        -subj "/C=US/ST=YES/L=SURE/O=CHAOS/OU=YES/CN=$DOMAIN_NAME"

    echo "Configuring Nginx as a reverse proxy with SSL..."
    # Create Nginx config file for Splunk
    cat <<-EOL > /etc/nginx/sites-available/splunk
		server {
				listen 80;
				server_name $DOMAIN_NAME;

				# Redirect all HTTP traffic to HTTPS
				location / {
						return 301 https://\$host\$request_uri;
				}
		}

		server {
				listen 443 ssl;
				server_name $DOMAIN_NAME;

				# SSL configuration
				ssl_certificate $CERT_PATH;
				ssl_certificate_key $CERT_KEY_PATH;

				# SSL parameters
				ssl_protocols TLSv1.2 TLSv1.3;
				ssl_ciphers HIGH:!aNULL:!MD5;
				ssl_prefer_server_ciphers on;

				# Proxy configuration
				location / {
						proxy_pass http://localhost:8000;
						proxy_set_header Host \$host;
						proxy_set_header X-Real-IP \$remote_addr;
						proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
						proxy_set_header X-Forwarded-Proto https;
				}
		}
		EOL

    # Enable the Splunk site and reload Nginx
    ln -s /etc/nginx/sites-available/splunk /etc/nginx/sites-enabled/
    systemctl reload nginx
}


download_splunk

start_splunk_service

configure_nginx_proxy

echo "Splunk installation and basic hardening completed with Nginx proxy on port 443!"
echo "Access Splunk Web at https://$DOMAIN_NAME"
