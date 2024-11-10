#!/bin/bash

##### Download CA certs for CHAOS #######

# Directory to store downloaded certificates
CERT_DIR="/usr/local/share/ca-certificates/chaos"
mkdir -p $CERT_DIR

CERT_INFO_FILE=CHAOS_DIR/x509/.spectr.yaml

# Checks for CA meta file
if [[ ! -f "$CERT_INFO_FILE" ]]; then
  echo "YAML file not found: $CERT_INFO_FILE"
  return 1
fi

# Extract URLs from the YAML file using yq
urls=$(yq -r '.active[].url' "$CERT_INFO_FILE")

for url in $urls; do
  echo "Downloading CA certificate from $url"
  cert_name=$(basename "$url")
  cert_path="$CERT_DIR/$cert_name"

  # Download the certificate
  if curl -sSL -o "$cert_path" $url; then
    echo "Successfully downloaded $cert_name"
  else
    echo "Failed to download $url"
    continue
  fi
done

# Update the CA certificates
update-ca-certificates
