#!/bin/bash


install_nerdctl(){
	LAST=`pwd`
	cd tmp/
	curl https://github.com/containerd/nerdctl/releases/download/v2.0.0/nerdctl-2.0.0-linux-amd64.tar.gz -O /tmp/nerdctl.tar.gz
	tar -xvzf /tmp/nerdctl.tar.gz
	install -o root -g root -t /usr/local/bin {nerdctl,containerd-rootless.sh,containerd-rootless-setuptool.sh}
	cd $LAST
}

install_rootless_containerd(){
	install_nerdctl
	containerd-rootless-setuptool.sh install
	containerd-rootless-setuptool.sh install-fuse-overlayfs
	docker context use rootless
}

setup_rootless_containerd(){
	sudo apt-get install -y dbus-user-session uidmap slirp4netns

	install_rootless_containerd

	# https://rootlesscontaine.rs/getting-started/common/cgroup2/#enabling-cpu-cpuset-and-io-delegation
	sudo mkdir -p /etc/systemd/system/user@.service.d
	cat <<-EOF | sudo tee /etc/systemd/system/user@.service.d/delegate.conf
	[Service]
	Delegate=cpu cpuset io memory pids
	EOF
	sudo systemctl daemon-reload

	cat <<-EOF > ~/.config/systemd/user/containerd.service.d/override.conf
	[Service]
	Environment="CONTAINERD_ROOTLESS_ROOTLESSKIT_PORT_DRIVER=slirp4netns"
	EOF

	cat <<-EOF > ~/.config/containerd/config.toml
	[proxy_plugins]
  [proxy_plugins."fuse-overlayfs"]
      type = "snapshot"
      address = "/run/user/$UID/containerd-fuse-overlayfs.sock"
	EOF

	systemctl --user daemon-reload 
	systemctl --user restart containerd


	# Set start at boot
	sudo loginctl enable-linger $(whoami)
	systemctl --user is-active dbus

}
