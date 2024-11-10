#!/bin/bash

setup_tailscale(){
	# Install and Up tailscale
	curl -fsSL https://tailscale.com/install.sh | sudo sh && \
	sudo tailscale up \
		--auth-key=$TAILSCALE_AUTH_KEY \
		--login-server=$TAILSCALE_SERVER
}
