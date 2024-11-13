#!/bin/bash

# CHAOS SETTINGS
CHAOS_DOMAIN=${CHAOS_DOMAIN:-"chaos.corp"}
PUBLIC_DOMAIN=${PUBLIC_DOMAIN:-"virtuconindustries.net"}

CHAOS_GROUP=${CHAOS_GROUP:-"chaos"}
CHAOS_DIR=${CHAOS_DIR:-"/opt/chaos"}

# SPLUNK SETTINGS
SPLUNK_HOST=${SPLUNK_HOST:-"splunk.$CHAOS_DOMAIN"}
SPLUNK_PORT=${SPLUNK_PORT:-"6514"}
SPLUNK_TOKEN=${SPLUNK_TOKEN:-"POTATO"}
SPLUNK_FALCO_INDEX=${SPLUNK_FALCO_INDEX:-"falco"}

SPLUNK_USER=${SPLUNK_USER:-"professor_chaos"}
SPLUNK_USER=${SPLUNK_USER:-"splonk1234"}

# Tailscale settings 
TAILSCALE_AUTH_KEY=${TAILSCALE_AUTH_KEY:-$1}
TAILSCALE_SERVER=${TAILSCALE_SERVER:-"https://controlplane.tailscale.com"}


# Directory containing files to be converted
SCRIPTS_PATH="`pwd`/chaotic/scripts"
x509_PATH="`pwd`/chaotic/x509"
# Path to the YAML file to update
YAML_FILE="cloud_init_splunk.yaml"


# Loop through each file in the directory
for file in "$SCRIPTS_PATH"/*; do
    # Check if it's a regular file
    if [[ -f "$file" ]]; then
        # Get the base64 encoded content of the file
        encoded_content=$(
            cat "$file" |
            sed -e "s/SPLUNK_HOST/$SPLUNK_HOST/g" |
            sed -e "s/SPLUNK_TOKEN/$SPLUNK_TOKEN/g" | 
            sed -e "s/SPLUNK_FALCO_INDEX/$SPLUNK_FALCO_INDEX/g" |
            sed -e "s;CHAOS_DIR;$CHAOS_DIR;g" |
            base64 | tr -d '\n'
        )
        
        # Get the file name without the directory path
        file_name=$(basename "$file")
        
        # Path in the destination for each file
        file_path="/opt/chaos/scripts/$file_name"

        entry_exists=$(yq eval ".write_files[] | select(.path == \"$file_path\")" "$YAML_FILE")

        if [[ -n "$entry_exists" ]]; then
            # Update only the specific entry matching the path
            yq eval --inplace \
                "(.write_files[] | select(.path == \"$file_path\")).encoding = \"base64\" | \
                 (.write_files[] | select(.path == \"$file_path\")).content = \"$encoded_content\" | \
                 (.write_files[] | select(.path == \"$file_path\")).owner = \"root:chaos\" | \
                 (.write_files[] | select(.path == \"$file_path\")).permissions = \"0o654\" | \
                (.write_files[] | select(.path == \"$file_path\")).defer = true"  \
                "$YAML_FILE"
        else
            # Add a new entry if it doesn't exist
            yq eval --inplace \
                ".write_files += [{\"encoding\": \"base64\", \"defer\": true, \"content\": \"$encoded_content\", \"owner\": \"root:chaos\", \"path\": \"$file_path\", \"permissions\": \"0o654\"}]" \
                "$YAML_FILE"
        fi
    fi
done


yq eval --inplace  ".ca_certs.trusted = []" $YAML_FILE
for file in "$x509_PATH"/*; do
    # Check if it's a regular file
    if [[ -f "$file" ]]; then
        # Get the base64 encoded content of the file
        encoded_content=$(cat "$file")
        yq eval --inplace \
            ".ca_certs.trusted  += [\"$encoded_content\"]" \
            "$YAML_FILE"
    
    fi
done

echo "Cloud-init entries have been updated in $YAML_FILE"

# yq eval --inplace ".rsyslog.configs  = [\"*.* @@$SPLUNK_HOST:$SPLUNK_PORT\"]" $YAML_FILE
yq eval --inplace ".hostname  = \"$1\"" $YAML_FILE
yq eval --inplace ".fqdn  = \"$1.$CHAOS_DOMAIN\"" $YAML_FILE

FALCO_CONFIG=$(
    cat `pwd`/chaotic/etc/falco/config.d/01-chaos.yaml |
    sed -e "s;CHAOS_DIR;$CHAOS_DIR;g" |
    base64 | tr -d '\n' 
)

entry_exists=$(yq eval ".write_files[] | select(.path == \"/etc/falco/config.d/01-chaos.yaml\")" "$YAML_FILE")

if [[ -n "$entry_exists" ]]; then
    # Update only the specific entry matching the path
    yq eval --inplace \
        "(.write_files[] | select(.path == \"/etc/falco/config.d/01-chaos.yaml\")).encoding = \"base64\" | \
            (.write_files[] | select(.path == \"/etc/falco/config.d/01-chaos.yaml\")).content = \"$FALCO_CONFIG\" | \
            (.write_files[] | select(.path == \"/etc/falco/config.d/01-chaos.yaml\")).owner = \"root:chaos\" | \
            (.write_files[] | select(.path == \"/etc/falco/config.d/01-chaos.yaml\")).permissions = \"0o654\" | \
            (.write_files[] | select(.path == \"/etc/falco/config.d/01-chaos.yaml\")).defer = true"  \
        "$YAML_FILE"
else
    # Add a new entry if it doesn't exist
    yq eval --inplace \
        ".write_files += [{\"encoding\": \"base64\", \"defer\": true, \"content\": \"$FALCO_CONFIG\", \"owner\": \"root:chaos\", \"path\": \"/etc/falco/config.d/01-chaos.yaml\", \"permissions\": \"0o654\"}]" \
        "$YAML_FILE"
fi



SPLUNK=$(
    cat `pwd`/chaotic/chaotic/install-splunk.sh |
    sed -e "s;SPLUNK_HOST;$SPLUNK_HOST;g" |
    sed -e "s;SPLUNK_PASS;$SPLUNK_PASS;g" |
    base64 | tr -d '\n' 
)

entry_exists=$(yq eval ".write_files[] | select(.path == \"/opt/install-splunk.sh\")" "$YAML_FILE")

if [[ -n "$entry_exists" ]]; then
    # Update only the specific entry matching the path
    yq eval --inplace \
        "(.write_files[] | select(.path == \"/opt/install-splunk.sh\")).encoding = \"base64\" | \
            (.write_files[] | select(.path == \"/opt/install-splunk.sh\")).content = \"$SPLUNK\" | \
            (.write_files[] | select(.path == \"/opt/install-splunk.sh\")).owner = \"root:chaos\" | \
            (.write_files[] | select(.path == \"/opt/install-splunk.sh\")).permissions = \"0o654\" | \
            (.write_files[] | select(.path == \"/opt/install-splunk.sh\")).defer = true"  \
        "$YAML_FILE"
else
    # Add a new entry if it doesn't exist
    yq eval --inplace \
        ".write_files += [{\"encoding\": \"base64\", \"defer\": true, \"content\": \"$SPLUNK\", \"owner\": \"root:chaos\", \"path\": \"/opt/install-splunk.sh\", \"permissions\": \"0o654\"}]" \
        "$YAML_FILE"
fi


(echo "cat << EOF | tee /mnt/pve/phoenix/snippets/$1.yaml";
cat $YAML_FILE; 
echo "EOF") | pbcopy

