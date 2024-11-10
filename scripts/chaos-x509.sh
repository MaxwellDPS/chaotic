#!/bin/bash

##### Download CA certs for CHAOS #######

# Directory to store downloaded certificates
local cert_dir="/usr/local/share/ca-certificates/chaos"
mkdir -p "$cert_dir"


CERT_INFO_FILE=$CHAOS_DIR/x509/.spectr.yaml

# Checks for CA meta file
if [[ ! -f "$CERT_INFO_FILE" ]]; then
  echo "YAML file not found: $CERT_INFO_FILE"
  return 1
fi

# Extract URLs from the YAML file using yq
urls=$(yq '.active[].url' "$CERT_INFO_FILE")

for url in $urls; do
  echo "Downloading CA certificate from $url"
  cert_name=$(basename "$url")
  cert_path="$cert_dir/$cert_name"

  # Download the certificate
  if curl -fsSL "$url" -o "$cert_path"; then
    echo "Successfully downloaded $cert_name"
  else
    echo "Failed to download $url"
    continue
  fi
done

# Update the CA certificates
update-ca-certificates
