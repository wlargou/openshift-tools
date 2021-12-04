#############################################################################
####  Purpose : Setup a local registry with Self-Signed Certificate    ######
####  Author : Largou Walid
####  Version : 1.0
#############################

## Variables
registryname=myregistry
registryuser=myuser
registrypassword=mypassword
registrypath=/opt/registry
registryport=5000
hostname=$HOSTNAME

## Setting up the registry 

mkdir -p ${registrypath}/{auth,certs,data}

yum install -y httpd-tools

htpasswd -bBc ${registrypath}/auth/htpasswd ${registryuser} ${registrypassword}

openssl req -newkey rsa:4096 -nodes -sha256 -keyout ${registrypath}/certs/domain.key -x509 -days 365 -out ${registrypath}/certs/domain.crt -addext "subjectAltName = DNS:${hostname}" -subj "/CN=${hostname}"
cp ${registrypath}/certs/domain.crt /etc/pki/ca-trust/source/anchors/
update-ca-trust

## Adding firewall Rules

firewall-cmd --add-port=${registryport}/tcp --zone=internal --permanent
firewall-cmd --add-port=${registryport}/tcp --zone=public --permanent
firewall-cmd --reload

##

sleep 5

## Running the container

podman run --name ${registryname} \
-p ${registryport}:${registryport} \
-v ${registrypath}/data:/var/lib/registry:z \
-v ${registrypath}/auth:/auth:z \
-e "REGISTRY_AUTH=htpasswd" \
-e "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" \
-e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
-v ${registrypath}/certs:/certs:z \
-e "REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt" \
-e "REGISTRY_HTTP_TLS_KEY=/certs/domain.key" \
-e REGISTRY_COMPATIBILITY_SCHEMA1_ENABLED=true \
-d \
docker.io/library/registry:latest

## Testing 

curl -u ${registryuser}:${registrypassword} https://${hostname}:${registryport}/v2/_catalog

podman login ${hostname}:${registryport} -u ${registryuser} -p ${registrypassword}




