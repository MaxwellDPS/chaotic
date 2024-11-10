#!/bin/bash

setup_k3s_audit(){
	sudo mkdir -p -m 700 /var/lib/rancher/k3s/server/logs

	cat <<-EOF | sudo tee /var/lib/rancher/k3s/server/audit.yaml
	apiVersion: audit.k8s.io/v1
	kind: Policy
	rules:
	- level: Metadata
	EOF

}

setup_k3s_config(){
	TAILSCALE_IP=`tailscale ip --4`
	LAB_IP=`ip -4 addr show | awk '/10\.42\./ {print $2}' | cut -d'/' -f1`

	sudo mkdir -p -m 700 /etc/rancher/k3s/

	cat <<-EOF | sudo tee /etc/rancher/k3s/config.yaml
	write-kubeconfig: $CHAOS_DIR/kubeconfig.yaml
	write-kubeconfig-mode: 660
	write-kubeconfig-group: $CHAOS_GROUP
	disable:
		- servicelb
		- traefik
	kube-apiserver-arg:
		- "enable-admission-plugins=NodeRestriction,EventRateLimit"
		- 'audit-log-path=/var/lib/rancher/k3s/server/logs/audit.log'
		- 'audit-policy-file=/var/lib/rancher/k3s/server/audit.yaml'
		- 'audit-log-maxage=30'
		- 'audit-log-maxbackup=10'
		- 'audit-log-maxsize=100'
	kube-controller-manager-arg:
		- 'terminated-pod-gc-threshold=10'
	kubelet-arg:
		- 'streaming-connection-idle-timeout=5m'
		- "tls-cipher-suites=TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305"
	tls-san:
		- "$HOSTNAME"
		- "$HOSTNAME.$CHAOS_DOMAIN"
		- "$HOSTNAME.$PUBLIC_DOMAIN"
		- "$TAILSCALE_IP"
		- "$LAB_IP"
		- "127.0.0.1"
	protect-kernel-defaults: true
	secrets-encryption: true
	cluster-domain: $CHAOS_DOMAIN
	cluster-cidr: $POD_CIDR
	service-cidr: $SVC_CIDR
	cluster-init: true
	selinux: true
	EOF

}

install_k3s(){
	setup_k3s_audit
	setup_k3s_config

	sudo curl -sL https://get.k3s.io/  -o $CHAOS_DIR/scripts/install.sh
	sudo chmod +x $CHAOS_DIR/scripts/install.sh
	sudo $CHAOS_DIR/scripts/install.sh server --config /etc/rancher/k3s/config.yaml

	sudo chmod -R 600 /var/lib/rancher/k3s/server/tls/*.crt

}

get_k3s_kubeconfig(){
	# Get kubeconfig with tailscale IP
	cat $CHAOS_DIR/kubeconfig.yaml | sed  -e "s/127.0.0.1/$HOSTNAME.$CHAOS_DOMAIN/g"
}