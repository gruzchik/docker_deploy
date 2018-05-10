#!/bin/bash
SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source ${SCRIPTPATH}/config

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

# generate nginx.conf file
[ ! -d ${SCRIPTPATH}/etc ] && mkdir -p ${SCRIPTPATH}/etc
cat <<EOF > ${SCRIPTPATH}/etc/nginx.conf
worker_processes 1;
#daemon off;
events {
    worker_connections 1024;
}
http {
        error_log /var/log/nginx/error.log;
        access_log /var/log/nginx/access.log;
        server {
            listen          80;
            server_name     nginx;
            location / {
                proxy_pass  http://apache;
            }
        }
}
EOF

# generate docker-compose file
[ ! -d /srv/log/nginx ] && mkdir -p /srv/log/nginx
cat <<EOF > ${SCRIPTPATH}/docker-compose.yml
version: '2'
services:
 nginx:
  image: ${NGINX_IMAGE}
  container_name: mir_nginx
  ports:
   - "${NGINX_PORT}:80"
  volumes:
   - ${SCRIPTPATH}/etc/nginx.conf:/etc/nginx/nginx.conf
   - /srv/log/nginx:/var/log/nginx
  links:
   - apache
 apache:
  image: ${APACHE_IMAGE}
  container_name: mir_apache
EOF

docker-compose up -d
