#!/bin/bash
# Generate certificates for the OpenSearch Container
set -euo pipefail
IFS=$'\n\t'

# Load .env file 
if [[ -f .env ]]; then
    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        if [[ ! $key =~ ^# && -n $key ]]; then
            export "$key"="$value"
        fi
    done < .env
fi

OPENSEARCH_DISTINGUISHED_NAME="/C=US/ST=CO/L=DENVER/O=SOFA"
HOSTNAME="${SOFA_HOSTNAME}"
IP_ADDRESS="${SOFA_IP_ADDRESS}"

mkdir -p certs/{ca,os-dashboards}

# Generate the Root CA
echo "Creating the root CA"
openssl genrsa -out certs/ca/ca.key 2048
openssl req -new -x509 -sha256 -days 1095 -subj "$OPENSEARCH_DISTINGUISHED_NAME/CN=CA" -key certs/ca/ca.key -out certs/ca/ca.pem

# Generate the Admin certs
echo "Creating the admin certs"
openssl genrsa -out certs/ca/admin-temp.key 2048
openssl pkcs8 -inform PEM -outform PEM -in certs/ca/admin-temp.key -topk8 -nocrypt -v1 PBE-SHA1-3DES -out certs/ca/admin.key
openssl req -new -subj "$OPENSEARCH_DISTINGUISHED_NAME/CN=ADMIN" -key certs/ca/admin.key -out certs/ca/admin.csr
openssl x509 -req -in certs/ca/admin.csr -CA certs/ca/ca.pem -CAkey certs/ca/ca.key -CAcreateserial -sha256 -out certs/ca/admin.pem

# Generate certs for OpenSearch Dashboards
echo "Creating the certs for OpenSearch Dashboards"
openssl genrsa -out certs/os-dashboards/os-dashboards-temp.key 2048
openssl pkcs8 -inform PEM -outform PEM -in certs/os-dashboards/os-dashboards-temp.key -topk8 -nocrypt -v1 PBE-SHA1-3DES -out certs/os-dashboards/os-dashboards.key
openssl req -new -subj "$OPENSEARCH_DISTINGUISHED_NAME/CN=os-dashboards" -key certs/os-dashboards/os-dashboards.key -out certs/os-dashboards/os-dashboards.csr
openssl x509 -req -extfile <(printf "subjectAltName=DNS:${HOSTNAME},IP:${IP_ADDRESS},DNS:os-dashboards") -in certs/os-dashboards/os-dashboards.csr -CA certs/ca/ca.pem -CAkey certs/ca/ca.key -CAcreateserial -sha256 -out certs/os-dashboards/os-dashboards.pem
rm certs/os-dashboards/os-dashboards-temp.key certs/os-dashboards/os-dashboards.csr

# Generate the certs for the OpenSearch Nodes
echo "Creating the certs for the OpenSearch nodes"
for NODE_NAME in "os-node-01" "os-node-02" "os-node-03"
do
    echo "Creating the certs for ${NODE_NAME}..."
    mkdir "certs/${NODE_NAME}"
    openssl genrsa -out "certs/$NODE_NAME/$NODE_NAME-temp.key" 2048
    openssl pkcs8 -inform PEM -outform PEM -in "certs/$NODE_NAME/$NODE_NAME-temp.key" -topk8 -nocrypt -v1 PBE-SHA1-3DES -out "certs/$NODE_NAME/$NODE_NAME.key"
    openssl req -new -subj "$OPENSEARCH_DISTINGUISHED_NAME/CN=$NODE_NAME" -key "certs/$NODE_NAME/$NODE_NAME.key" -out "certs/$NODE_NAME/$NODE_NAME.csr"
    openssl x509 -req -extfile <(printf "subjectAltName=DNS:${HOSTNAME},IP:${IP_ADDRESS},DNS:$NODE_NAME") -in "certs/$NODE_NAME/$NODE_NAME.csr" -CA certs/ca/ca.pem -CAkey certs/ca/ca.key -CAcreateserial -sha256 -out "certs/$NODE_NAME/$NODE_NAME.pem"
    rm "certs/$NODE_NAME/$NODE_NAME-temp.key" "certs/$NODE_NAME/$NODE_NAME.csr"
done

echo "Created all the certs. Exiting..."
exit 0

