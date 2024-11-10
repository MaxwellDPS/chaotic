#!/bin/bash

get_kubeconfig(){
	# Get kubeconfig with tailscale IP
	cat ~/.kube/config | sed  -e "s/127.0.0.1/$TAILSCALE_IP/g"
}

# Install hardned minikube
setup_minikube(){
	# Gets IPs for minikue certs and bind
	TAILSCALE_IP=`tailscale ip --4`
	LAB_IP=`ip -4 addr show | awk '/10\.42\./ {print $2}' | cut -d'/' -f1`

	echo "[+] GOT IPs LAB: $LAB_IP TS: $TAILSCALE_IP"

	# Install Minikube
	curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube_latest_amd64.deb
	sudp dpkg -i minikube_latest_amd64.deb

	# Launch Minikube with gvizor
	minikube start \
			--driver docker \
			--container-runtime=containerd  \
			--docker-opt containerd=/var/run/containerd/containerd.sock \
			--addons gvisor \
			--apiserver-ips $LAB_IP,$TAILSCALE_IP,127.0.0.1 \
			--apiserver-names $HOSTNAME,$HOSTNAME.$CHAOS_DOMAIN,$HOSTNAME.$PUBLIC_DOMAIN \
			--delete-on-failure \
			--dns-domain $CHAOS_DOMAIN \
			--embed-certs \
			--extra-config kubeadm.pod-network-cidr=$POD_CIDR \
			--feature-gates AppArmor=true \
			--interactive false \
			--kubernetes-version $KUBERNETES_VERSION \
			--listen-address 127.0.0.1 \
			--listen-address $LAB_IP \
			--listen-address $TAILSCALE_IP \
			--service-cluster-ip-range $SVC_CIDR

	# Get the external port mapped to container port 8443
	container_id=$(docker ps --filter "publish=8443" --format "{{.ID}}")
	external_port=$(docker inspect --format='{{(index (index .NetworkSettings.Ports "8443/tcp") 0).HostPort}}' "$container_id")

	# Allow inbound access for the kubeapi from CHAOS MGMT
	sudo ufw allow from 192.168.51.0/24 to any port $external_port
	# Allow inbound access for the kubeapi from TAILSCALE
	sudo ufw allow from 100.64.0.0/10 to any port $external_port
}
