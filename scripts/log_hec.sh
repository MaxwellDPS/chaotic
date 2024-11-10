#!/bin/bash

# Read input from stdin
input=$(cat)
log_json=$(echo "$input" | jq --arg hostname "`hostname`" '. | {host: $hostname, sourcetype: "falco", index: "SPLUNK_FALCO_INDEX", event: .}')

curl -k -d "$log_json" \
    -H "Authorization: Splunk SPLUNK_TOKEN" \
    "https://SPLUNK_HOST:8088/services/collector/event"