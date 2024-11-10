#!/bin/bash

install_gvisor(){
	curl -fsSL https://gvisor.dev/archive.key | sudo gpg --dearmor -o /usr/share/keyrings/gvisor-archive-keyring.gpg
	echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/gvisor-archive-keyring.gpg] https://storage.googleapis.com/gvisor/releases release main" | sudo tee /etc/apt/sources.list.d/gvisor.list > /dev/null

	sudo apt-get update && sudo apt-get install -y runsc

	# https://gist.github.com/Frichetten/c77ee24b12edd2ab852738fc8221a1f1#configure-containerd
	sudo cat <<-EOF > /var/lib/rancher/k3s/agent/etc/containerd/config.toml.tmpl
	{{ template "base" . }}

	[plugins."io.containerd.runtime.v1.linux"]
	shim_debug = true
	[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runsc]
	runtime_type = "io.containerd.runsc.v1"
	EOF

	sudo systemctl restart k3s

	# Install Runtime
	cat <<-EOF | kubectl apply -f -
	apiVersion: node.k8s.io/v1
	kind: RuntimeClass
	metadata:
		name: gvisor
	handler: runsc
	EOF

}
