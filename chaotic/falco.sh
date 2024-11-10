#!/bin/sh

install_falco(){
	curl -fsSL https://falco.org/repo/falcosecurity-packages.asc | \
	sudo gpg --dearmor -o /usr/share/keyrings/falco-archive-keyring.gpg

	echo "deb [signed-by=/usr/share/keyrings/falco-archive-keyring.gpg] https://download.falco.org/packages/deb stable main" | \
	sudo tee -a /etc/apt/sources.list.d/falcosecurity.list

	sudo apt install -y falco

	sudo systemctl list-units | grep falco
	sudo systemctl stop falco*

	sudo falcoctl driver config --type modern_ebpf
	sudo systemctl start falco-modern-bpf.service
	sudo systemctl enable falco-modern-bpf.service

	sudo systemctl unmask falcoctl-artifact-follow.service
	sudo systemctl enable falcoctl-artifact-follow.service
	sudo systemctl list-units | grep falco


	# Falco configuration for rootless Docker
	curl -FsSL $REPO_URL/etc/falco/config.d/01-chaos.yaml |\
    sed -e "s/CHAOS_DIR/$CHAOS_DIR/g" |\
    sudo tee /etc/falco/config.d/01-chaos.yaml

	# Restart Falco to apply the new configuration
	sudo systemctl restart falco
}
