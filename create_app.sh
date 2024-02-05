#!/bin/bash
set -e

# AUTHOR: Damir Dzeko Antic <Damir.DzekoAntic at combis.hr>
# LICENSE: MIT

# SCRIPT FOR CREATION OF CLUSTER RESOURCES NEEDED TO RUN THE APPLICATION
# testDbCon.py -- MariaDB connectivity and resilience test
# ======================================================================

# PREREQUISITES:
#
# 1) run the following commands while logged into OpenShift Platform CLI
#    and having selected oc project to add this workload to
#
#    oc login # --insecure-skip-tls-verify=true
#    oc project test-mariadbcon
#
#    OCP_DOMAIN=$(oc cluster-info | sed -e 's!.*//api\.!!' -e 's!:.*!!' -e '1!d')
#    NS=`oc project -q`
#
# 2) having uploaded the aplication container image to local registry
#    beforehand, using:
#
#    podman login -u bogus -p $(oc whoami -t) default-route-openshift-image-registry.apps.${OCP_DOMAIN}
#    podman load -i mariadb-testdbcon.tar  # local ctr image file, produced by docker save -o ...
#    podman tag docker.io/library/test1db:latest default-route-openshift-image-registry.apps.${OCP_DOMAIN}/${NS}/mariadb-testdbcon:latest
#    podman push default-route-openshift-image-registry.apps.${OCP_DOMAIN}/${NS}/mariadb-testdbcon:latest
#
# 3) having "mariadb" hostname DNS-resolveable or via local /etc/hosts entry
#    (if using different name change it in the line where MYSQL_IPADDRESS is defined)


OCP_DOMAIN=$(oc cluster-info | sed -e 's!.*//api\.!!' -e 's!:.*!!' -e '1!d')
NS=`oc project -q`

MYSQL_SERVICE=external-mariadb-service

# hostname used for pods inside the cluster environment
MYSQL_HOST=${MYSQL_SERVICE}.${NS}.svc.cluster.local
MYSQL_PORT=3306
MYSQL_DBNAME="testdb"

# real external IP address (VIP/Floating IP) of the MariaDB Galera cluster
MYSQL_IPADDRESS=$(ping -q -c1 -t1 mariadb | tr -d '()' | awk '/^PING/{print $3}')

TESTDBCON_IMAGE="image-registry.openshift-image-registry.svc:5000/${NS}/mariadb-testdbcon:latest"

RNDM=$(echo $RANDOM | sha256sum | head -c 6)
MYSQL_TEST_TBL="test_${RNDM}"

# recapitulation what's gonna go down and collect /go ahead/
echo "=== Creating MariaDB connectivity test app ==="
echo "Parameters for creation of service/endpoint/deployment:"
echo "  OCP Domain=$OCP_DOMAIN, Project=$NS"
echo "  External IP address: ${MYSQL_IPADDRESS} <-> OCP service EP:"
echo "    $MYSQL_HOST:$MYSQL_PORT"
echo "  Container Image: ${TESTDBCON_IMAGE}"
echo "  Test DB name: ${MYSQL_DBNAME}, table name: ${MYSQL_TEST_TBL}"
echo "=============================================="
MYSQL_USER="testuser"
MYSQL_PASSWORD=""
if [[ -z "$MYSQL_PASSWORD" ]]; then
    echo -n "Password of '$MYSQL_USER' test DB user:"    # Prompt for entering password 
    read -s MYSQL_PASSWORD       # read password by suppressing it using -s option
    echo
fi

echo "Press <Ctrl-C> to abort, or <Enter> to go ahead ... "
read go_ahead

# export environment variables for envsubst
export OCP_DOMAIN NS TESTDBCON_IMAGE MYSQL_SERVICE MYSQL_HOST MYSQL_PORT MYSQL_IPADDRESS MYSQL_DBNAME MYSQL_USER MYSQL_PASSWORD MYSQL_TEST_TBL

cat external-mariadb-svc.yaml external-mariadb-ep.yaml deployment.yaml | envsubst | tee app.yaml | oc apply -f -

echo
echo "You can undo this deployment using:"
echo "  oc delete deploy mariadb-testdbcon"
echo "  oc delete ep external-mariadb-service"
echo "  oc delete svc external-mariadb-service"
echo 
echo "This app by design deploys paused, start it using:"
echo "  oc rollout resume deployment/mariadb-testdbcon"
echo
echo "Find the pod running this app:"
echo "  oc get pods --selector app=mariadb-testdbcon"
echo
echo "Monitor the execution using:"
echo "  oc logs -f deploy/mariadb-testdbcon"
echo
echo "Stop the app by scaling pod count to 0:"
echo "  oc scale deployment mariadb-testdbcon --replicas=0"
echo
