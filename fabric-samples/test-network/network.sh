#!/bin/bash

# SPDX-License-Identifier: Apache-2.0


# This script brings up a Hyperledger Fabric network for testing smart contracts
# and applications. The test network consists of two organizations with one
# peer each, and a single node Raft ordering service. Users can also use this
# script to create a channel deploy a chaincode on the channel
#
# prepending $PWD/../bin to PATH to ensure we are picking up the correct binaries
# this may be commented out to resolve installed version of tools if desired
#
# However using PWD in the path has the side effect that location that
# this script is run from is critical. To ease this, get the directory
# this script is actually in and infer location from there. (putting first)

ROOTDIR=$(cd "$(dirname "$0")" && pwd)
export PATH=${ROOTDIR}/../bin:${PWD}/../bin:$PATH
export FABRIC_CFG_PATH=${PWD}/configtx
export VERBOSE=false

pushd ${ROOTDIR} > /dev/null
trap "popd > /dev/null" EXIT

. scripts/utils.sh

: ${CONTAINER_CLI:="docker"}
if command -v ${CONTAINER_CLI}-compose > /dev/null 2>&1; then
    : ${CONTAINER_CLI_COMPOSE:="${CONTAINER_CLI}-compose"}
else
    : ${CONTAINER_CLI_COMPOSE:="${CONTAINER_CLI} compose"}
fi
infoln "Using ${CONTAINER_CLI} and ${CONTAINER_CLI_COMPOSE}"

# Obtain CONTAINER_IDS and remove them
# This function is called when you bring a network down
function clearContainers() {
  infoln "Removing remaining containers"
  ${CONTAINER_CLI} rm -f $(${CONTAINER_CLI} ps -aq --filter label=service=hyperledger-fabric) 2>/dev/null || true
  ${CONTAINER_CLI} rm -f $(${CONTAINER_CLI} ps -aq --filter name='dev-peer*') 2>/dev/null || true
  ${CONTAINER_CLI} kill "$(${CONTAINER_CLI} ps -q --filter name=ccaas)" 2>/dev/null || true
}

# Delete any images that were generated as a part of this setup
# specifically the following images are often left behind:
# This function is called when you bring the network down
function removeUnwantedImages() {
  infoln "Removing generated chaincode docker images"
  ${CONTAINER_CLI} image rm -f $(${CONTAINER_CLI} images -aq --filter reference='dev-peer*') 2>/dev/null || true
}

# Versions of fabric known not to work with the test network
NONWORKING_VERSIONS="^1\.0\. ^1\.1\. ^1\.2\. ^1\.3\. ^1\.4\."

# Do some basic sanity checking to make sure that the appropriate versions of fabric
# binaries/images are available. In the future, additional checking for the presence
# of go or other items could be added.
function checkPrereqs() {
  ## Check if your have cloned the peer binaries and configuration files.
  peer version > /dev/null 2>&1

  if [[ $? -ne 0 || ! -d "../config" ]]; then
    errorln "Peer binary and configuration files not found.."
    errorln
    errorln "Follow the instructions in the Fabric docs to install the Fabric Binaries:"
    errorln "https://hyperledger-fabric.readthedocs.io/en/latest/install.html"
    exit 1
  fi
  # use the fabric tools container to see if the samples and binaries match your
  # docker images
  LOCAL_VERSION=$(peer version | sed -ne 's/^ Version: //p')
  DOCKER_IMAGE_VERSION=$(${CONTAINER_CLI} run --rm hyperledger/fabric-tools:latest peer version | sed -ne 's/^ Version: //p')

  infoln "LOCAL_VERSION=$LOCAL_VERSION"
  infoln "DOCKER_IMAGE_VERSION=$DOCKER_IMAGE_VERSION"

  if [ "$LOCAL_VERSION" != "$DOCKER_IMAGE_VERSION" ]; then
    warnln "Local fabric binaries and docker images are out of  sync. This may cause problems."
  fi

  for UNSUPPORTED_VERSION in $NONWORKING_VERSIONS; do
    infoln "$LOCAL_VERSION" | grep -q $UNSUPPORTED_VERSION
    if [ $? -eq 0 ]; then
      fatalln "Local Fabric binary version of $LOCAL_VERSION does not match the versions supported by the test network."
    fi

    infoln "$DOCKER_IMAGE_VERSION" | grep -q $UNSUPPORTED_VERSION
    if [ $? -eq 0 ]; then
      fatalln "Fabric Docker image version of $DOCKER_IMAGE_VERSION does not match the versions supported by the test network."
    fi
  done

  ## check for cfssl binaries
  if [ "$CRYPTO" == "cfssl" ]; then
  
    cfssl version > /dev/null 2>&1
    if [[ $? -ne 0 ]]; then
      errorln "cfssl binary not found.."
      errorln
      errorln "Follow the instructions to install the cfssl and cfssljson binaries:"
      errorln "https://github.com/cloudflare/cfssl#installation"
      exit 1
    fi
  fi

  ## Check for fabric-ca
  if [ "$CRYPTO" == "Certificate Authorities" ]; then

    fabric-ca-client version > /dev/null 2>&1
    if [[ $? -ne 0 ]]; then
      errorln "fabric-ca-client binary not found.."
      errorln
      errorln "Follow the instructions in the Fabric docs to install the Fabric Binaries:"
      errorln "https://hyperledger-fabric.readthedocs.io/en/latest/install.html"
      exit 1
    fi
    CA_LOCAL_VERSION=$(fabric-ca-client version | sed -ne 's/ Version: //p')
    CA_DOCKER_IMAGE_VERSION=$(${CONTAINER_CLI} run --rm hyperledger/fabric-ca:latest fabric-ca-client version | sed -ne 's/ Version: //p' | head -1)
    infoln "CA_LOCAL_VERSION=$CA_LOCAL_VERSION"
    infoln "CA_DOCKER_IMAGE_VERSION=$CA_DOCKER_IMAGE_VERSION"

    if [ "$CA_LOCAL_VERSION" != "$CA_DOCKER_IMAGE_VERSION" ]; then
      warnln "Local fabric-ca binaries and docker images are out of sync. This may cause problems."
    fi
  fi
}

# Before you can bring up a network, each organization needs to generate the crypto
# material that will define that organization on the network. Because Hyperledger
# Fabric is a permissioned blockchain, each node and user on the network needs to
# use certificates and keys to sign and verify its actions. In addition, each user
# needs to belong to an organization that is recognized as a member of the network.
# You can use the Cryptogen tool or Fabric CAs to generate the organization crypto
# material.

# By default, the sample network uses cryptogen. Cryptogen is a tool that is
# meant for development and testing that can quickly create the certificates and keys
# that can be consumed by a Fabric network. The cryptogen tool consumes a series
# of configuration files for each organization in the "organizations/cryptogen"
# directory. Cryptogen uses the files to generate the crypto  material for each
# org in the "organizations" directory.

# You can also use Fabric CAs to generate the crypto material. CAs sign the certificates
# and keys that they generate to create a valid root of trust for each organization.
# The script uses Docker Compose to bring up three CAs, one for each peer organization
# and the ordering organization. The configuration file for creating the Fabric CA
# servers are in the "organizations/fabric-ca" directory. Within the same directory,
# the "registerEnroll.sh" script uses the Fabric CA client to create the identities,
# certificates, and MSP folders that are needed to create the test network in the
# "organizations/ordererOrganizations" directory.


function createOrgs() {
  if [ -d "organizations/peerOrganizations" ]; then
    rm -Rf organizations/peerOrganizations && rm -Rf organizations/ordererOrganizations
  fi

  infoln "Generating certificates using cryptogen tool"

  infoln "Creating OEM Identities"
  set -x
  cryptogen generate --config=./organizations/cryptogen/crypto-config-oem.yaml --output="organizations"
  res=$?
  { set +x; } 2>/dev/null
  if [ $res -ne 0 ]; then
    fatalln "Failed to generate certificates for OEM"
  fi

  infoln "Creating Supplier Identities"
  set -x
  cryptogen generate --config=./organizations/cryptogen/crypto-config-supplier.yaml --output="organizations"
  res=$?
  { set +x; } 2>/dev/null
  if [ $res -ne 0 ]; then
    fatalln "Failed to generate certificates for Supplier"
  fi

  infoln "Creating Airline Identities"
  set -x
  cryptogen generate --config=./organizations/cryptogen/crypto-config-airline.yaml --output="organizations"
  res=$?
  { set +x; } 2>/dev/null
  if [ $res -ne 0 ]; then
    fatalln "Failed to generate certificates for Airline"
  fi
  
  infoln "Creating Orderer Org Identities"

  set -x
  cryptogen generate --config=./organizations/cryptogen/crypto-config-orderer.yaml --output="organizations"
  res=$?
  { set +x; } 2>/dev/null
  if [ $res -ne 0 ]; then
    fatalln "Failed to generate certificates..."
  fi

  infoln "Generating CCP files for OEM, Supplier, and Airline"
  ./organizations/ccp-generate.sh
}
# Once you create the organization crypto material, you need to create the
# genesis block of the application channel.

# The configtxgen tool is used to create the genesis block. Configtxgen consumes a
# "configtx.yaml" file that contains the definitions for the sample network. The
# genesis block is defined using the "ChannelUsingRaft" profile at the bottom
# of the file. This profile defines an application channel consisting of our two Peer Orgs.
# The peer and ordering organizations are defined in the "Profiles" section at the
# top of the file. As part of each organization profile, the file points to the
# location of the MSP directory for each member. This MSP is used to create the channel
# MSP that defines the root of trust for each organization. In essence, the channel
# MSP allows the nodes and users to be recognized as network members.
#
# If you receive the following warning, it can be safely ignored:
#
# [bccsp] GetDefault -> WARN 001 Before using BCCSP, please call InitFactories(). Falling back to bootBCCSP.
#
# You can ignore the logs regarding intermediate certs, we are not using them in
# this crypto implementation.

# After we create the org crypto material and the application channel genesis block,
# we can now bring up the peers and ordering service. By default, the base
# file for creating the network is "docker-compose-test-net.yaml" in the ``docker``
# folder. This file defines the environment variables and file mounts that
# point the crypto material and genesis block that were created in earlier.

# Bring up the peer and orderer nodes using docker compose.

function networkUp() {
  checkPrereqs
  if [ ! -d "organizations/peerOrganizations" ]; then
    createOrgs
  fi

  COMPOSE_FILES="-f compose/${COMPOSE_FILE_BASE} -f compose/${CONTAINER_CLI}/${CONTAINER_CLI}-${COMPOSE_FILE_BASE}"

  DOCKER_SOCK="${DOCKER_SOCK}" ${CONTAINER_CLI_COMPOSE} ${COMPOSE_FILES} up -d 2>&1

  $CONTAINER_CLI ps -a
  if [ $? -ne 0 ]; then
    fatalln "Unable to start network"
  fi
}
# call the script to create the channel, join the peers of org1 and org2,
# and then update the anchor peers for each organization
function createChannel() {
  bringUpNetwork="false"

  if ! $CONTAINER_CLI info > /dev/null 2>&1 ; then
    fatalln "$CONTAINER_CLI network is required to be running to create a channel"
  fi
  # check if all containers are present
  CONTAINERS=($($CONTAINER_CLI ps | grep hyperledger/ | awk '{print $2}'))
  len=$(echo ${#CONTAINERS[@]})

  if [[ $len -lt 4 ]] || [[ ! -d "organizations/peerOrganizations" ]]; then
    bringUpNetwork="true"
  else
    echo "Network Running Already"
  fi

  if [ $bringUpNetwork == "true"  ]; then
    infoln "Bringing up network"
    networkUp
  fi
  
  # Ensure CHANNEL_NAME is provided as an argument
  if [ -z "$CHANNEL_NAME" ]; then
    fatalln "Channel name not provided. Use: ./network.sh createChannel <CHANNEL_NAME>"
  fi

  # now run the script that creates a channel. This script uses configtxgen once
  # to create the channel creation transaction and the anchor peer updates.
  scripts/createChannel.sh $CHANNEL_NAME $CLI_DELAY $MAX_RETRY $VERBOSE
}
##################### UNCHANGED FROM ORIGINAL NETWORK.SH ###################################
# Add other functions like deployCC, networkDown, etc., as needed from the original script.
## Call the script to deploy a chaincode to the channel
function deployCC() {
  scripts/deployCC.sh $CHANNEL_NAME $CC_NAME $CC_SRC_PATH $CC_SRC_LANGUAGE $CC_VERSION $CC_SEQUENCE $CC_INIT_FCN $CC_END_POLICY $CC_COLL_CONFIG $CLI_DELAY $MAX_RETRY $VERBOSE

  if [ $? -ne 0 ]; then
    fatalln "Deploying chaincode failed"
  fi
}

## Call the script to deploy a chaincode to the channel
function deployCCAAS() {
  scripts/deployCCAAS.sh $CHANNEL_NAME $CC_NAME $CC_SRC_PATH $CCAAS_DOCKER_RUN $CC_VERSION $CC_SEQUENCE $CC_INIT_FCN $CC_END_POLICY $CC_COLL_CONFIG $CLI_DELAY $MAX_RETRY $VERBOSE $CCAAS_DOCKER_RUN

  if [ $? -ne 0 ]; then
    fatalln "Deploying chaincode-as-a-service failed"
  fi
}

## Call the script to package the chaincode
function packageChaincode() {

  infoln "Packaging chaincode"

  scripts/packageCC.sh $CC_NAME $CC_SRC_PATH $CC_SRC_LANGUAGE $CC_VERSION true

  if [ $? -ne 0 ]; then
    fatalln "Packaging the chaincode failed"
  fi

}

## Call the script to list installed and committed chaincode on a peer
function listChaincode() {

  export FABRIC_CFG_PATH=${PWD}/../config

  . scripts/envVar.sh
  . scripts/ccutils.sh

  setGlobals $ORG

  println
  queryInstalledOnPeer
  println

  listAllCommitted

}

## Call the script to invoke 
function invokeChaincode() {

  export FABRIC_CFG_PATH=${PWD}/../config

  . scripts/envVar.sh
  . scripts/ccutils.sh

  setGlobals $ORG

  chaincodeInvoke $ORG $CHANNEL_NAME $CC_NAME $CC_INVOKE_CONSTRUCTOR

}

## Call the script to query chaincode 
function queryChaincode() {

  export FABRIC_CFG_PATH=${PWD}/../config
  
  . scripts/envVar.sh
  . scripts/ccutils.sh

  setGlobals $ORG

  chaincodeQuery $ORG $CHANNEL_NAME $CC_NAME $CC_QUERY_CONSTRUCTOR

}


function networkDown() {
  local temp_compose=$COMPOSE_FILE_BASE
  COMPOSE_FILE_BASE=compose-bft-test-net.yaml
  COMPOSE_BASE_FILES="-f compose/${COMPOSE_FILE_BASE} -f compose/${CONTAINER_CLI}/${CONTAINER_CLI}-${COMPOSE_FILE_BASE}"
  COMPOSE_COUCH_FILES="-f compose/${COMPOSE_FILE_COUCH} -f compose/${CONTAINER_CLI}/${CONTAINER_CLI}-${COMPOSE_FILE_COUCH}"
  COMPOSE_CA_FILES="-f compose/${COMPOSE_FILE_CA} -f compose/${CONTAINER_CLI}/${CONTAINER_CLI}-${COMPOSE_FILE_CA}"
  COMPOSE_FILES="${COMPOSE_BASE_FILES} ${COMPOSE_COUCH_FILES} ${COMPOSE_CA_FILES}"

  if [ "${CONTAINER_CLI}" == "docker" ]; then
    DOCKER_SOCK=$DOCKER_SOCK ${CONTAINER_CLI_COMPOSE} ${COMPOSE_FILES} down --volumes --remove-orphans
  elif [ "${CONTAINER_CLI}" == "podman" ]; then
    ${CONTAINER_CLI_COMPOSE} ${COMPOSE_FILES} down --volumes
  else
    fatalln "Container CLI  ${CONTAINER_CLI} not supported"
  fi

  COMPOSE_FILE_BASE=$temp_compose

  if [ "$MODE" != "restart" ]; then
    # Adjusted to remove volumes for the new organization containers
    ${CONTAINER_CLI} volume rm docker_orderer.example.com docker_peerOEM.example.com docker_peerAirline.example.com docker_peerSupplier.example.com
    # Cleanup the chaincode containers
    clearContainers
    # Cleanup images
    removeUnwantedImages
    # Remove orderer block and other channel configuration transactions and certs
    ${CONTAINER_CLI} run --rm -v "$(pwd):/data" busybox sh -c 'cd /data && rm -rf system-genesis-block/*.block organizations/peerOrganizations organizations/ordererOrganizations'
    ## Remove fabric ca artifacts for the new organizations
    ${CONTAINER_CLI} run --rm -v "$(pwd):/data" busybox sh -c 'cd /data && rm -rf organizations/fabric-ca/oem organizations/fabric-ca/airline organizations/fabric-ca/supplier'
    # Remove channel and script artifacts
    ${CONTAINER_CLI} run --rm -v "$(pwd):/data" busybox sh -c 'cd /data && rm -rf channel-artifacts log.txt *.tar.gz'
    ${CONTAINER_CLI} run --rm -v "$(pwd):/data" busybox sh -c 'cd /data && rm -rf system-genesis-block/*.block organizations/peerOrganizations organizations/ordererOrganizations'
## Remove fabric ca artifacts for Org1, Org2, OrdererOrg, and new organizations (OEM, Airline, Supplier)
    ${CONTAINER_CLI} run --rm -v "$(pwd):/data" busybox sh -c 'cd /data && rm -rf \
        organizations/fabric-ca/ordererOrg/msp \
        organizations/fabric-ca/ordererOrg/tls-cert.pem \
        organizations/fabric-ca/ordererOrg/ca-cert.pem \
        organizations/fabric-ca/ordererOrg/IssuerPublicKey \
        organizations/fabric-ca/ordererOrg/IssuerRevocationPublicKey \
        organizations/fabric-ca/ordererOrg/fabric-ca-server.db \
        organizations/fabric-ca/oem/msp \
        organizations/fabric-ca/oem/tls-cert.pem \
        organizations/fabric-ca/oem/ca-cert.pem \
        organizations/fabric-ca/oem/IssuerPublicKey \
        organizations/fabric-ca/oem/IssuerRevocationPublicKey \
        organizations/fabric-ca/oem/fabric-ca-server.db \
        organizations/fabric-ca/airline/msp \
        organizations/fabric-ca/airline/tls-cert.pem \
        organizations/fabric-ca/airline/ca-cert.pem \
        organizations/fabric-ca/airline/IssuerPublicKey \
        organizations/fabric-ca/airline/IssuerRevocationPublicKey \
        organizations/fabric-ca/airline/fabric-ca-server.db \
        organizations/fabric-ca/supplier/msp \
        organizations/fabric-ca/supplier/tls-cert.pem \
        organizations/fabric-ca/supplier/ca-cert.pem \
        organizations/fabric-ca/supplier/IssuerPublicKey \
        organizations/fabric-ca/supplier/IssuerRevocationPublicKey \
        organizations/fabric-ca/supplier/fabric-ca-server.db'
    # Remove channel and script artifacts
    ${CONTAINER_CLI} run --rm -v "$(pwd):/data" busybox sh -c 'cd /data && rm -rf channel-artifacts log.txt *.tar.gz'
      
  
  fi
}
###############################################################################################
# Parse commandline args
# ## Parse mode
# if [[ $# -lt 1 ]] ; then
#   printHelp
#   exit 0
# else
#   MODE=$1
#   shift
# fi

# ## if no parameters are passed, show the help for cc
# if [ "$MODE" == "cc" ] && [[ $# -lt 1 ]]; then
#   printHelp $MODE
#   exit 0
# fi
# # Add logic to parse other command-line arguments as needed.

# # Determine mode of operation and printing out what we asked for
# if [ "$MODE" == "up" ]; then
#   infoln "Starting network with new configuration"
#   networkUp
# elif [ "$MODE" == "createChannel" ]; then
#   infoln "Creating new channels"
#   createChannel
# elif [ "$MODE" == "down" ]; then
#   infoln "Stopping network"
#   networkDown
# # Add other modes as needed
# else
#   printHelp
#   exit 1
# fi

### SIGRID ###

. ./network.config

# Existing Docker Compose files for the test network, CouchDB, and CAs
COMPOSE_FILE_BASE=compose-test-net.yaml
COMPOSE_FILE_COUCH=compose-couch.yaml
COMPOSE_FILE_CA=compose-ca.yaml

# New Docker Compose files for the new organizations
COMPOSE_FILE_NEW_ORG_BASE=compose-new-org.yaml  # Replace 'new-org' with your organization's name
COMPOSE_FILE_NEW_ORG_COUCH=compose-couch-new-org.yaml  # If using CouchDB
COMPOSE_FILE_NEW_ORG_CA=compose-ca-new-org.yaml  # If using CAs

# Rest of the script...

# Get docker sock path from environment variable
SOCK="${DOCKER_HOST:-/var/run/docker.sock}"
DOCKER_SOCK="${SOCK##unix://}"

# BFT activated flag
BFT=0

# Parse commandline args

## Parse mode
if [[ $# -lt 1 ]] ; then
  printHelp
  exit 0
else
  MODE=$1
  shift
fi

## if no parameters are passed, show the help for cc
if [ "$MODE" == "cc" ] && [[ $# -lt 1 ]]; then
  printHelp $MODE
  exit 0
fi

# parse subcommands if used
if [[ $# -ge 1 ]] ; then
  key="$1"
  # check for the createChannel subcommand
  if [[ "$key" == "createChannel" ]]; then
      export MODE="createChannel"
      shift
  # check for the cc command
  elif [[ "$MODE" == "cc" ]]; then
    if [ "$1" != "-h" ]; then
      export SUBCOMMAND=$key
      shift
    fi
  fi
fi


# parse flags

while [[ $# -ge 1 ]] ; do
  key="$1"
  case $key in
  -h )
    printHelp $MODE
    exit 0
    ;;
  -c )
    CHANNEL_NAME="$2"
    shift
    ;;
  -bft )
    BFT=1
    ;;
  -ca )
    CRYPTO="Certificate Authorities"
    ;;
  -cfssl )
    CRYPTO="cfssl"
    ;;
  -r )
    MAX_RETRY="$2"
    shift
    ;;
  -d )
    CLI_DELAY="$2"
    shift
    ;;
  -s )
    DATABASE="$2"
    shift
    ;;
  -ccl )
    CC_SRC_LANGUAGE="$2"
    shift
    ;;
  -ccn )
    CC_NAME="$2"
    shift
    ;;
  -ccv )
    CC_VERSION="$2"
    shift
    ;;
  -ccs )
    CC_SEQUENCE="$2"
    shift
    ;;
  -ccp )
    CC_SRC_PATH="$2"
    shift
    ;;
  -ccep )
    CC_END_POLICY="$2"
    shift
    ;;
  -cccg )
    CC_COLL_CONFIG="$2"
    shift
    ;;
  -cci )
    CC_INIT_FCN="$2"
    shift
    ;;
  -ccaasdocker )
    CCAAS_DOCKER_RUN="$2"
    shift
    ;;
  -verbose )
    VERBOSE=true
    ;;
  -org )
    ORG="$2"
    shift
    ;;
  -i )
    IMAGETAG="$2"
    shift
    ;;
  -cai )
    CA_IMAGETAG="$2"
    shift
    ;;
  -ccic )
    CC_INVOKE_CONSTRUCTOR="$2"
    shift
    ;;
  -ccqc )
    CC_QUERY_CONSTRUCTOR="$2"
    shift
    ;;    
  * )
    errorln "Unknown flag: $key"
    printHelp
    exit 1
    ;;
  esac
  shift
done

## Check if user attempts to use BFT orderer and CA together
if [[ $BFT -eq 1 && "$CRYPTO" == "Certificate Authorities" ]]; then
  fatalln "This sample does not yet support the use of consensus type BFT and CA together."
fi

if [ $BFT -eq 1 ]; then
  export FABRIC_CFG_PATH=${PWD}/bft-config
  COMPOSE_FILE_BASE=compose-bft-test-net.yaml
fi

# Are we generating crypto material with this command?
if [ ! -d "organizations/peerOrganizations" ]; then
  CRYPTO_MODE="with crypto from '${CRYPTO}'"
else
  CRYPTO_MODE=""
fi

# Determine mode of operation and printing out what we asked for
if [ "$MODE" == "prereq" ]; then
  infoln "Installing binaries and fabric images. Fabric Version: ${IMAGETAG}  Fabric CA Version: ${CA_IMAGETAG}"
  installPrereqs
elif [ "$MODE" == "up" ]; then
  infoln "Starting nodes with CLI timeout of '${MAX_RETRY}' tries and CLI delay of '${CLI_DELAY}' seconds and using database '${DATABASE}' ${CRYPTO_MODE}"
  networkUp
elif [ "$MODE" == "createChannel" ]; then
  infoln "Creating channel '${CHANNEL_NAME}'."
  infoln "If network is not up, starting nodes with CLI timeout of '${MAX_RETRY}' tries and CLI delay of '${CLI_DELAY}' seconds and using database '${DATABASE} ${CRYPTO_MODE}"
  createChannel $BFT
elif [ "$MODE" == "down" ]; then
  infoln "Stopping network"
  networkDown
elif [ "$MODE" == "restart" ]; then
  infoln "Restarting network"
  networkDown
  networkUp
elif [ "$MODE" == "deployCC" ]; then
  infoln "deploying chaincode on channel '${CHANNEL_NAME}'"
  deployCC
elif [ "$MODE" == "deployCCAAS" ]; then
  infoln "deploying chaincode-as-a-service on channel '${CHANNEL_NAME}'"
  deployCCAAS
elif [ "$MODE" == "cc" ] && [ "$SUBCOMMAND" == "package" ]; then
  packageChaincode
elif [ "$MODE" == "cc" ] && [ "$SUBCOMMAND" == "list" ]; then
  listChaincode
elif [ "$MODE" == "cc" ] && [ "$SUBCOMMAND" == "invoke" ]; then
  invokeChaincode
elif [ "$MODE" == "cc" ] && [ "$SUBCOMMAND" == "query" ]; then
  queryChaincode
else
  printHelp
  exit 1
fi
