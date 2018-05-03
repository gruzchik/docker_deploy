#!/bin/bash

# check if docker was installed
if [ ! -x "$(command -v docker)" ] || [ ! -x "$(command -v docker-compose)" ]; then
	# prepare docker env
	apt-get update
	apt-get install -y apt-transport-https ca-certificates curl software-properties-common
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -

	# add repo  and install docker
	add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
	apt-get update && apt-get install -y docker-ce docker-compose
fi
