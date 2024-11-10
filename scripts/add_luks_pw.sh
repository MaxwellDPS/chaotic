#!/bin/bash

echo "Attempting to find LUKS partition automatically..."
luks_device=$(lsblk -o NAME,TYPE,FSTYPE -nr | awk '$2 == "crypt" {print "/dev/" $1}' | head -n 1)

if [[ -z "$luks_device" ]]; then
    echo "Error: No LUKS partition found."
    return 1
fi

echo "Found LUKS device: $luks_device"

echo "Adding a new password to LUKS device: $luks_device"
cryptsetup luksAddKey "$luks_device"

if [[ \$? -eq 0 ]]; then
    echo "New LUKS password added successfully."
else
    echo "Failed to add new LUKS password."
    return 1
fi
