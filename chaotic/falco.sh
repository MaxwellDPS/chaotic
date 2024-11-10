#!/bin/sh

install_falco(){
    # Download signing key
	curl -fsSL https://falco.org/repo/falcosecurity-packages.asc | \
	sudo gpg --dearmor -o /usr/share/keyrings/falco-archive-keyring.gpg

    # Setup Falco in package manager
	echo "deb [signed-by=/usr/share/keyrings/falco-archive-keyring.gpg] https://download.falco.org/packages/deb stable main" | \
	sudo tee -a /etc/apt/sources.list.d/falcosecurity.list

    # Install Falco
	FALCO_FRONTEND=noninteractive FALCO_DRIVER_CHOICE=modern_ebpf  sudo apt install -y falco

    # Show running drivers and stop all
	sudo systemctl list-units | grep falco
	sudo systemctl stop falco*

    # Set falco to modern eBPF
	sudo falcoctl driver config --type modern_ebpf
	sudo systemctl start falco-modern-bpf.service
	sudo systemctl enable falco-modern-bpf.service

    # Enable the Falco rule updates
	sudo systemctl unmask falcoctl-artifact-follow.service
	sudo systemctl enable falcoctl-artifact-follow.service

    # Show falco status
	sudo systemctl list-units | grep falco

	# Falco configuration for rootless Docker
	sudo cp $CHAOS_DIR/etc/falco/config.d/01-chaos.yaml     /etc/falco/config.d/01-chaos.yaml
    sed -i -e "s/CHAOS_DIR/$CHAOS_DIR/g"                    /etc/falco/config.d/01-chaos.yaml
    
	# Restart Falco to apply the new configuration
	sudo systemctl restart falco
}
