#!/bin/bash

echo "Fetching latest Cloudflare IP ranges..."
CLOUDFLARE_IP_RANGES=$(curl -s https://www.cloudflare.com/ips-v4; curl -s https://www.cloudflare.com/ips-v6)

# Remove old Cloudflare IP rules
echo "Removing old Cloudflare IP rules..."
for rule in $(ufw status numbered | grep "ALLOW OUT" | grep -E "Cloudflare" | awk -F'[][]' '{print $2}' | sort -nr); do
    echo "y" | ufw delete $rule
done

# Add new Cloudflare IP rules
echo "Adding new Cloudflare IP rules..."
for ip_range in $CLOUDFLARE_IP_RANGES; do
    ufw allow out to "$ip_range" comment "Cloudflare"
done