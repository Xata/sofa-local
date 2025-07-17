#!/bin/bash

# Exit on error, undefined variable, or pipe failure
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

# Define some variables
HOSTNAME="${SOFA_HOSTNAME}"

# Generate certificates
if [[ -d certs ]]; then
  echo "Certs directory already exists..."
else
  echo "Certs directory does not exist..."
  echo "Creating certs..."
  bash generate-certificates.sh
fi

# Generate password hash for the admin user
ADMIN_PASSWORD_HASH=$(docker run --rm opensearchproject/opensearch:3.1.0 bash -c "
  cd /usr/share/opensearch/plugins/opensearch-security/tools && 
  bash hash.sh -p ${OPENSEARCH_ADMIN_PASSWORD}
")

# Generate password hash for the kibanaserver user
KIBANASERVER_PASSWORD_HASH=$(docker run --rm opensearchproject/opensearch:3.1.0 bash -c "
  cd /usr/share/opensearch/plugins/opensearch-security/tools && 
  bash hash.sh -p ${OPENSEARCH_KIBANASERVER_PASSWORD}
")

# Generate password hash for the anomalyadmin user
ANOMALYADMIN_PASSWORD_HASH=$(docker run --rm opensearchproject/opensearch:3.1.0 bash -c "
  cd /usr/share/opensearch/plugins/opensearch-security/tools && 
  bash hash.sh -p ${OPENSEARCH_ANOMALYADMIN_PASSWORD}
")

# Generate a password hash for the kibanaro user
KIBANARO_PASSWORD_HASH=$(docker run --rm opensearchproject/opensearch:3.1.0 bash -c "
  cd /usr/share/opensearch/plugins/opensearch-security/tools && 
  bash hash.sh -p ${OPENSEARCH_KIBANARO_PASSWORD}
")

# Generate a password hash for the logstash user
LOGSTASH_PASSWORD_HASH=$(docker run --rm opensearchproject/opensearch:3.1.0 bash -c "
  cd /usr/share/opensearch/plugins/opensearch-security/tools && 
  bash hash.sh -p ${OPENSEARCH_LOGSTASH_PASSWORD}
")

# Generate a password for the READALL user
READALL_PASSWORD_HASH=$(docker run --rm opensearchproject/opensearch:3.1.0 bash -c "
  cd /usr/share/opensearch/plugins/opensearch-security/tools && 
  bash hash.sh -p ${OPENSEARCH_READALL_PASSWORD}
")

# Generate a password for the snapshotrestore user
SNAPSHOTRESTORE_PASSWORD_HASH=$(docker run --rm opensearchproject/opensearch:3.1.0 bash -c "
  cd /usr/share/opensearch/plugins/opensearch-security/tools && 
  bash hash.sh -p ${OPENSEARCH_SNAPSHOTRESTORE_PASSWORD}
")

# Check to see if the config directory exists
if [ ! -d "./config/opensearch-security/" ]; then
    mkdir -p ./config/opensearch-security/
fi

# Check to see if an internal_users.yml already exists
if [ -f "config/opensearch-security/internal_users.yml" ]; then
    echo "File exists. Deleting it to create new hashs. Cause security or something..."
    rm config/opensearch-security/internal_users.yml
    echo "File has been deleted!"
else
    echo "File does not exist moving on..."
fi

# Create the internal_users.yml file
echo "Creating internal_users.yml..."
cat > ./config/opensearch-security/internal_users.yml << EOF
---
_meta:
  type: "internalusers"
  config_version: 2

admin:
  hash: "${ADMIN_PASSWORD_HASH}"
  reserved: true
  backend_roles:
  - "admin"
  description: "Admin user"

kibanaserver:
  hash: "${KIBANASERVER_PASSWORD_HASH}"
  reserved: true
  description: "Kibanaserver user"

anomalyadmin:
  hash: "${ANOMALYADMIN_PASSWORD_HASH}"
  reserved: false
  opendistro_security_roles:
  - "anomaly_full_access"
  description: "Anomaly Admin user"

kibanaro:
  hash: "${KIBANARO_PASSWORD_HASH}"
  reserved: false
  backend_roles:
  - "kibanauser"
  - "readall"
  description: "Kibanaro user"

logstash:
  hash: "${LOGSTASH_PASSWORD_HASH}"
  reserved: false
  backend_roles:
  - "logstash"
  description: "Logstash user"

readall:
  hash: "${READALL_PASSWORD_HASH}"
  reserved: false
  backend_roles:
  - "readall"
  description: "Readall user"

snapshotrestore:
  hash: "${SNAPSHOTRESTORE_PASSWORD_HASH}"
  reserved: false
  backend_roles:
  - "snapshotrestore"
  description: "Snapshotrestore user"
EOF

# Check to see if opensearch.yml already exists
if [ -f "config/opensearch.yml" ]; then
    echo "File exists. Deleting it..."
    rm config/opensearch.yml
    echo "File has been deleted!"
else
    echo "File does not exist moving on..."
fi

# Generate the opensearch.yml file
echo "Creating opensearch.yml..."
cat > ./config/opensearch.yml << EOF
plugins.security.allow_unsafe_democertificates: false
plugins.security.ssl.http.enabled: true
plugins.security.ssl.http.pemtrustedcas_filepath: certificates/ca/ca.pem
plugins.security.ssl.transport.enabled: true
plugins.security.ssl.transport.pemtrustedcas_filepath: certificates/ca/ca.pem
plugins.security.ssl.transport.enforce_hostname_verification: true

plugins.security.authcz.admin_dn:
  - 'CN=ADMIN,O=SOFA,L=DENVER,ST=CO,C=US'
plugins.security.nodes_dn:
  - 'CN=os-node-00,O=SOFA,L=DENVER,ST=CO,C=US'
  - 'CN=os-node-01,O=SOFA,L=DENVER,ST=CO,C=US'
  - 'CN=os-node-02,O=SOFA,L=DENVER,ST=CO,C=US'
  - 'CN=os-node-03,O=SOFA,L=DENVER,ST=CO,C=US'
EOF


# Check to see if tenants.yml already exists
if [ -f "config/opensearch-security/tenants.yml" ]; then
    echo "File exists. Deleting it..."
    rm config/opensearch-security/tenants.yml
    echo "File has been deleted!"
else
    echo "File does not exist moving on..."
fi

# Generate the tenants.yml file
echo "Creating the tenants.yml file..."
cat > ./config/opensearch-security/tenants.yml << EOF
---
_meta:
  type: "tenants"
  config_version: 2

## Default admin user tenant
admin_tenant:
  reserved: false
  description: "Admin user tenant"

global_analyst_tenant:
  reserved: false
  description: "Tenant for all analysts to analyze security logs"
EOF

# Start containers
echo "Starting the containers and waiting"
docker compose up -d
sleep 20

# Initialize the security plugin on the OpenSearch nodes
echo "Initializing the security plugin within the nodes"
for NODE_NAME in "os-node-01" "os-node-02" "os-node-03"
do
    docker compose exec $NODE_NAME bash -c "chmod +x plugins/opensearch-security/tools/securityadmin.sh && bash plugins/opensearch-security/tools/securityadmin.sh -cd config/opensearch-security -icl -nhnv -cacert config/certificates/ca/ca.pem -cert config/certificates/ca/admin.pem -key config/certificates/ca/admin.key -h $HOSTNAME"
    sleep 15
done
echo "Security Plugins have been initialized!!"

# Restart the dashboards container
DASHBOARDS_CONTAINER_ID=$(docker compose ps -q "opensearch-dashboards")
if [[ -n "$DASHBOARDS_CONTAINER_ID" ]]; then
  echo "Restarting OpenSearch Dashboards: $DASHBOARDS_CONTAINER_ID"
  docker restart "$DASHBOARDS_CONTAINER_ID"
  sleep 3
else
  echo "Could not find container for OpenSearch Dashboards. Something is wrong. Sorry..."
  exit 1
fi

echo "You should be able to access OpenSearch Dashboards at: https://$HOSTNAME:5601"
echo "You can destroy this by running: docker compose down --volumes --remove-orphans"
exit 0







