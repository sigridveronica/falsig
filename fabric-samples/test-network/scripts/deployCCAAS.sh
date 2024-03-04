#!/bin/bash

source scripts/utils.sh

CHANNEL_NAME=${1:-"mychannel"}
CC_NAME=${2}
CC_SRC_PATH=${3}
CCAAS_DOCKER_RUN=${4:-"true"}
CC_VERSION=${5:-"1.0"}
CC_SEQUENCE=${6:-"1"}
CC_INIT_FCN=${7:-"NA"}
CC_END_POLICY=${8:-"NA"}
CC_COLL_CONFIG=${9:-"NA"}
DELAY=${10:-"3"}
MAX_RETRY=${11:-"5"}
VERBOSE=${12:-"false"}

CCAAS_SERVER_PORT=9999

: ${CONTAINER_CLI:="docker"}
if command -v ${CONTAINER_CLI}-compose > /dev/null 2>&1; then
    : ${CONTAINER_CLI_COMPOSE:="${CONTAINER_CLI}-compose"}
else
    : ${CONTAINER_CLI_COMPOSE:="${CONTAINER_CLI} compose"}
fi
infoln "Using ${CONTAINER_CLI} and ${CONTAINER_CLI_COMPOSE}"

println "executing with the following"
println "- CHANNEL_NAME: ${C_GREEN}${CHANNEL_NAME}${C_RESET}"
println "- CC_NAME: ${C_GREEN}${CC_NAME}${C_RESET}"
println "- CC_SRC_PATH: ${C_GREEN}${CC_SRC_PATH}${C_RESET}"
println "- CC_VERSION: ${C_GREEN}${CC_VERSION}${C_RESET}"
println "- CC_SEQUENCE: ${C_GREEN}${CC_SEQUENCE}${C_RESET}"
println "- CC_END_POLICY: ${C_GREEN}${CC_END_POLICY}${C_RESET}"
println "- CC_COLL_CONFIG: ${C_GREEN}${CC_COLL_CONFIG}${C_RESET}"
println "- CC_INIT_FCN: ${C_GREEN}${CC_INIT_FCN}${C_RESET}"
println "- CCAAS_DOCKER_RUN: ${C_GREEN}${CCAAS_DOCKER_RUN}${C_RESET}"
println "- DELAY: ${C_GREEN}${DELAY}${C_RESET}"
println "- MAX_RETRY: ${C_GREEN}${MAX_RETRY}${C_RESET}"
println "- VERBOSE: ${C_GREEN}${VERBOSE}${C_RESET}"

FABRIC_CFG_PATH=$PWD/../config/

# Validation checks for CC_NAME and CC_SRC_PATH

if [ "$CC_END_POLICY" = "NA" ]; then
  CC_END_POLICY=""
else
  CC_END_POLICY="--signature-policy $CC_END_POLICY"
fi

if [ "$CC_COLL_CONFIG" = "NA" ]; then
  CC_COLL_CONFIG=""
else
  CC_COLL_CONFIG="--collections-config $CC_COLL_CONFIG"
fi
# Import utils
. scripts/envVar.sh
. scripts/ccutils.sh

# Package Chaincode
packageChaincode() {

  address="{{.peername}}_${CC_NAME}_ccaas:${CCAAS_SERVER_PORT}"
  prefix=$(basename "$0")
  tempdir=$(mktemp -d -t "$prefix.XXXXXXXX") || error_exit "Error creating temporary directory"
  label=${CC_NAME}_${CC_VERSION}
  mkdir -p "$tempdir/src"

cat > "$tempdir/src/connection.json" <<CONN_EOF
{
  "address": "${address}",
  "dial_timeout": "10s",
  "tls_required": false
}
CONN_EOF

   mkdir -p "$tempdir/pkg"

cat << METADATA-EOF > "$tempdir/pkg/metadata.json"
{
    "type": "ccaas",
    "label": "$label"
}
METADATA-EOF

    tar -C "$tempdir/src" -czf "$tempdir/pkg/code.tar.gz" .
    tar -C "$tempdir/pkg" -czf "$CC_NAME.tar.gz" metadata.json code.tar.gz
    rm -Rf "$tempdir"

    PACKAGE_ID=$(peer lifecycle chaincode calculatepackageid ${CC_NAME}.tar.gz)
  
    successln "Chaincode is packaged  ${address}"
}
# Build Docker Images

buildDockerImages() {
  # if set don't build - useful when you want to debug yourself
  if [ "$CCAAS_DOCKER_RUN" = "true" ]; then
    # build the docker container
    infoln "Building Chaincode-as-a-Service docker image '${CC_NAME}' '${CC_SRC_PATH}'"
    infoln "This may take several minutes..."
    set -x
    ${CONTAINER_CLI} build -f $CC_SRC_PATH/Dockerfile -t ${CC_NAME}_ccaas_image:latest --build-arg CC_SERVER_PORT=9999 $CC_SRC_PATH >&log.txt
    res=$?
    { set +x; } 2>/dev/null
    cat log.txt
    verifyResult $res "Docker build of chaincode-as-a-service container failed"
    successln "Docker image '${CC_NAME}_ccaas_image:latest' built succesfully"
  else
    infoln "Not building docker image; this the command we would have run"
    infoln "   ${CONTAINER_CLI} build -f $CC_SRC_PATH/Dockerfile -t ${CC_NAME}_ccaas_image:latest --build-arg CC_SERVER_PORT=9999 $CC_SRC_PATH"
  fi
}

# Start Docker Container
# Function modified to start containers for OEM, Airline, and Supplier
startDockerContainer() {
  if [ "$CCAAS_DOCKER_RUN" = "true" ]; then
    infoln "Starting the Chaincode-as-a-Service docker container for OEM, Airline, and Supplier..."
    # Start container for OEM
    ${CONTAINER_CLI} run --rm -d --name peer0oem_${CC_NAME}_ccaas \
                  --network fabric_test \
                  -e CHAINCODE_SERVER_ADDRESS=0.0.0.0:${CCAAS_SERVER_PORT} \
                  -e CHAINCODE_ID=$PACKAGE_ID -e CORE_CHAINCODE_ID_NAME=$PACKAGE_ID \
                    ${CC_NAME}_ccaas_image:latest
    # Start container for Airline
    ${CONTAINER_CLI} run --rm -d --name peer0airline_${CC_NAME}_ccaas \
                  --network fabric_test \
                  -e CHAINCODE_SERVER_ADDRESS=0.0.0.0:${CCAAS_SERVER_PORT} \
                  -e CHAINCODE_ID=$PACKAGE_ID -e CORE_CHAINCODE_ID_NAME=$PACKAGE_ID \
                    ${CC_NAME}_ccaas_image:latest
    # Start container for Supplier
    ${CONTAINER_CLI} run --rm -d --name peer0supplier_${CC_NAME}_ccaas \
                  --network fabric_test \
                  -e CHAINCODE_SERVER_ADDRESS=0.0.0.0:${CCAAS_SERVER_PORT} \
                  -e CHAINCODE_ID=$PACKAGE_ID -e CORE_CHAINCODE_ID_NAME=$PACKAGE_ID \
                    ${CC_NAME}_ccaas_image:latest
  else
    infoln "Not starting docker containers; these are the commands we would have run"
    # Display commands for OEM, Airline, and Supplier
  fi
}

# Build the docker image 
buildDockerImages

## Package the chaincode
packageChaincode

## Install chaincode on peers of OEM, Airline, and Supplier
infoln "Installing chaincode on peer0.OEM..."
installChaincode OEM
infoln "Installing chaincode on peer0.Airline..."
installChaincode Airline
infoln "Installing chaincode on peer0.Supplier..."
installChaincode Supplier

resolveSequence

## Query whether the chaincode is installed
queryInstalled OEM
queryInstalled Airline
queryInstalled Supplier

## Approve the definition for OEM, Airline, and Supplier
approveForMyOrg OEM
approveForMyOrg Airline
approveForMyOrg Supplier

## Check whether the chaincode definition is ready to be committed
checkCommitReadiness OEM "\"OEMMSP\": true" "\"AirlineMSP\": true" "\"SupplierMSP\": true"
checkCommitReadiness Airline "\"OEMMSP\": true" "\"AirlineMSP\": true" "\"SupplierMSP\": true"
checkCommitReadiness Supplier "\"OEMMSP\": true" "\"AirlineMSP\": true" "\"SupplierMSP\": true"

## Now that we know for sure all orgs have approved, commit the definition
commitChaincodeDefinition OEM Airline Supplier

## Query on all orgs to see that the definition committed successfully
queryCommitted OEM
queryCommitted Airline
queryCommitted Supplier

# Start the container
startDockerContainer

## Invoke the chaincode - this does require that the chaincode have the 'initLedger' method defined
if [ "$CC_INIT_FCN" = "NA" ]; then
  infoln "Chaincode initialization is not required"
else
  chaincodeInvokeInit OEM Airline Supplier
fi

exit 0