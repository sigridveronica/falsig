#!/bin/bash

# This is a collection of bash functions used by different scripts

# imports
. scripts/utils.sh

export CORE_PEER_TLS_ENABLED=true
export ORDERER_CA=${PWD}/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem

# Define an associative array for organization names and their CA files
declare -A ORG_NAMES=( [1]="oem" [2]="supplier" [3]="airline" )
declare -A ORG_CA_FILES=(
    [1]="${PWD}/organizations/peerOrganizations/oem.example.com/tlsca/tlsca.oem.example.com-cert.pem"
    [2]="${PWD}/organizations/peerOrganizations/supplier.example.com/tlsca/tlsca.supplier.example.com-cert.pem"
    [3]="${PWD}/organizations/peerOrganizations/airline.example.com/tlsca/tlsca.airline.example.com-cert.pem"
)

# Set environment variables for the peer org
setGlobals() {
  local USING_ORG=""
  if [ -z "$OVERRIDE_ORG" ]; then
    USING_ORG=$1
  else
    USING_ORG="${OVERRIDE_ORG}"
  fi
  infoln "Using organization ${ORG_NAMES[$USING_ORG]}"
  if [ -n "${ORG_NAMES[$USING_ORG]}" ]; then
    export CORE_PEER_LOCALMSPID="${ORG_NAMES[$USING_ORG]}MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=${ORG_CA_FILES[$USING_ORG]}
    export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/${ORG_NAMES[$USING_ORG]}.example.com/users/Admin@${ORG_NAMES[$USING_ORG]}.example.com/msp
    export CORE_PEER_ADDRESS=localhost:$((7051 + ($USING_ORG - 1) * 2000))
  else
    errorln "ORG Unknown"
  fi

  if [ "$VERBOSE" == "true" ]; then
    env | grep CORE
  fi
}

# Set environment variables for use in the CLI container
setGlobalsCLI() {
  setGlobals $1

  local USING_ORG=""
  if [ -z "$OVERRIDE_ORG" ]; then
    USING_ORG=$1
  else
    USING_ORG="${OVERRIDE_ORG}"
  fi
  if [ -n "${ORG_NAMES[$USING_ORG]}" ]; then
    export CORE_PEER_ADDRESS=peer0.${ORG_NAMES[$USING_ORG]}.example.com:$((7051 + ($USING_ORG - 1) * 2000))
  else
    errorln "ORG Unknown"
  fi
}

# parsePeerConnectionParameters $@
# Helper function that sets the peer connection parameters for a chaincode operation
parsePeerConnectionParameters() {
  PEER_CONN_PARMS=()
  PEERS=""
  while [ "$#" -gt 0 ]; do
    setGlobals $1
    PEER="peer0.${ORG_NAMES[$1]}.example.com"
    ## Set peer addresses
    if [ -z "$PEERS" ]; then
        PEERS="$PEER"
    else
        PEERS="$PEERS $PEER"
    fi
    PEER_CONN_PARMS=("${PEER_CONN_PARMS[@]}" --peerAddresses $CORE_PEER_ADDRESS)
    ## Set path to TLS certificate
    CA=${ORG_CA_FILES[$1]}
    TLSINFO=(--tlsRootCertFiles "${CA}")
    PEER_CONN_PARMS=("${PEER_CONN_PARMS[@]}" "${TLSINFO[@]}")
    # shift by one to get to the next organization
    shift
  done
}

verifyResult() {
  if [ $1 -ne 0 ]; then
    fatalln "$2"
  fi
}