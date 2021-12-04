#########################################
####  Purpose : Setup mirroring    ######
####  Author : Largou Walid        ######
####  Version : 1.0                ######
#########################################

## Variables
redhatlogin=user@company.com
redhatpass=xxxxxx
quaylogin=user@company.com
quaypass=xxxxxx
registryuser=myuser
registrypassword=mypassword
registryport=5000
hostname=$HOSTNAME
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