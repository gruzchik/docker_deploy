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

# generate root certificate
[ ! -d ${SCRIPTPATH}/certs ] && mkdir -p ${SCRIPTPATH}/certs

openssl genrsa -out ${SCRIPTPATH}/certs/root-ca.key 2048
openssl req -x509 -days 365 -new -nodes -key ${SCRIPTPATH}/certs/root-ca.key -sha256 -out ${SCRIPTPATH}/certs/root-ca.crt -subj "/C=UA/ST=Kharkiv/L=Kharkiv/O=Nure/OU=Admin/CN=rootCA"
# generate nginx cert
openssl genrsa -out ${SCRIPTPATH}/certs/web.key 2048
openssl req -nodes -new -sha256 -key ${SCRIPTPATH}/certs/web.key -out ${SCRIPTPATH}/certs/web.csr -subj "/C=UA/ST=Kharkiv/L=Kharkiv/O=Datacenter/OU=Server/CN=${HOST_NAME}"
openssl x509 -req -extfile <(printf "subjectAltName=IP:${EXTERNAL_IP},DNS:www.${HOST_NAME}") -days 365 -in ${SCRIPTPATH}/certs/web.csr -CA ${SCRIPTPATH}/certs/root-ca.crt -CAkey ${SCRIPTPATH}/certs/root-ca.key -CAcreateserial -out ${SCRIPTPATH}/certs/web.crt

# add SSL_CHAIN
cat ${SCRIPTPATH}/certs/web.crt ${SCRIPTPATH}/certs/root-ca.crt > ${SCRIPTPATH}/certs/web-bundle.crt
cp -aR ${SCRIPTPATH}/certs/* /etc/ssl/certs/
SSL_KEY="/etc/ssl/certs/web.key"
SSL_CHAIN="/etc/ssl/certs/web-bundle.crt"

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
            #listen          80;
	    listen 80 ssl;
            ssl on;
            ssl_certificate ${SSL_CHAIN};
            ssl_certificate_key ${SSL_KEY};
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
   - /etc/ssl/certs:/etc/ssl/certs
  links:
   - apache
 apache:
  image: ${APACHE_IMAGE}
  container_name: mir_apache
EOF

cd ${SCRIPTPATH} && docker-compose up -d
