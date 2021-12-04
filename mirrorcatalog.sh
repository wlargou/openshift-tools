#############################################################################
####  Purpose : Setup a local registry with Self-Signed Certificate    ######
####  Author : Largou Walid
####  Version : 1.0
#############################

## Variables
registryname=myregistry
registryuser=walid
registrypassword=walid
registrypath=/opt/registry
registryport=5000
hostname=belrapss001.eurafric-information.com

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


#############################################################################
####  Purpose : Setup mirroring    ######
####  Author : Largou Walid
####  Version : 1.0
#############################

## Variables
redhatlogin=l.walid@powerm.ma
redhatpass=xxxxxx
quaylogin=l.walid@powerm.ma
quaypass=xxxxxx
registryuser=walid
registrypassword=walid
registryport=5000
hostname=belrapss001.eurafric-information.com
registryname=${hostname}:${registryport}
REG_CREDS=/run/user/0/containers/auth.json
tempdir=/opt/tools

## Tools
mkdir -p $tempdir
cd  $tempdir
wget https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/latest-4.6/opm-linux.tar.gz
wget https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/latest-4.6/openshift-client-linux.tar.gz
wget https://github.com/fullstorydev/grpcurl/releases/download/v1.8.5/grpcurl_1.8.5_linux_x86_64.tar.gz

tar -xvf grpcurl_1.8.5_linux_x86_64.tar.gz
tar -xvf openshift-client-linux.tar.gz 
tar -xvf opm-linux.tar.gz

cp opm oc kubectl grpcurl /usr/local/bin/

#### Mirroring

podman login registry.redhat.io -u ${redhatlogin} -p ${redhatpass}

podman login quay.io -u ${quaylogin} -p ${quaypass}

podman run -d -p50051:50051 registry.redhat.io/redhat/redhat-operator-index:v4.8

opm index prune -f registry.redhat.io/redhat/redhat-operator-index:v4.8 -p openshift-gitops-operator,openshift-pipelines-operator-rh,eap  -t ${registryname}/openshift4-ohi/redhat-operator-index:v4.8

podman login ${hostname}:${registryport} -u ${registryuser} -p ${registrypassword}

podman push ${registryname}/openshift4-ohi/redhat-operator-index:v4.8

oc adm catalog mirror ${registryname}/openshift4-ohi/redhat-operator-index:v4.8 file:///local/index  -a ${REG_CREDS} --insecure --index-filter-by-os=Linux/amd64

