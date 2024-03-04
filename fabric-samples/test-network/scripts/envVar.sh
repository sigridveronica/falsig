#!/bin/bash

# This is a collection of bash functions used by different scripts

# imports
. scripts/utils.sh

export CORE_PEER_TLS_ENABLED=true
export ORDERER_CA=organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem

# Define an associative array for organization names and their CA files
declare -A ORG_NAMES=( [1]="oem" [2]="supplier" [3]="airline" )
declare -A ORG_CA_FILES=(
    [1]="organizations/peerOrganizations/oem.example.com/tlsca/tlsca.oem.example.com-cert.pem"
    [2]="organizations/peerOrganizations/supplier.example.com/tlsca/tlsca.supplier.example.com-cert.pem"
    [3]="organizations/peerOrganizations/airline.example.com/tlsca/tlsca.airline.example.com-cert.pem"
)

# Set environment variables for the peer org
# setGlobals() {
#   local USING_ORG=""
#   if [ -z "$OVERRIDE_ORG" ]; then
#     USING_ORG=$1
#   else
#     USING_ORG="${OVERRIDE_ORG}"
#   fi
#   infoln "Using organization ${ORG_NAMES[$USING_ORG]}"
#   if [ -n "${ORG_NAMES[$USING_ORG]}" ]; then
#     export CORE_PEER_LOCALMSPID="${ORG_NAMES[$USING_ORG]}MSP"
#     export CORE_PEER_TLS_ROOTCERT_FILE=${ORG_CA_FILES[$USING_ORG]}
#     export CORE_PEER_MSPCONFIGPATH=organizations/peerOrganizations/${ORG_NAMES[$USING_ORG]}.example.com/users/Admin@${ORG_NAMES[$USING_ORG]}.example.com/msp
#     export CORE_PEER_ADDRESS=localhost:$((7051 + ($USING_ORG - 1) * 2000))
#   else
#     errorln "ORG Unknown"
#   fi

#   if [ "$VERBOSE" == "true" ]; then
#     env | grep CORE
#   fi
# }

function setGlobals() {
  ORG=$1
  PEER=$2

  if [ "$ORG" == "OEM" ]; then
    CORE_PEER_LOCALMSPID="OEMMSP"
    CORE_PEER_TLS_ROOTCERT_FILE=$PWD/organizations/peerOrganizations/oem.example.com/peers/$PEER.oem.example.com/tls/ca.crt
    CORE_PEER_MSPCONFIGPATH=$PWD/organizations/peerOrganizations/oem.example.com/users/Admin@oem.example.com/msp
    if [ "$PEER" == "QA1.1" ]; then
      CORE_PEER_ADDRESS=localhost:7051
    elif [ "$PEER" == "QA1.2" ]; then
      CORE_PEER_ADDRESS=localhost:8051
    elif [ "$PEER" == "SW1.1" ]; then
      CORE_PEER_ADDRESS=localhost:9051
    elif [ "$PEER" == "SW1.2" ]; then
      CORE_PEER_ADDRESS=localhost:10051
    elif [ "$PEER" == "SW1.3" ]; then
      CORE_PEER_ADDRESS=localhost:11051
    fi
  elif [ "$ORG" == "Supplier" ]; then
    CORE_PEER_LOCALMSPID="SupplierMSP"
    CORE_PEER_TLS_ROOTCERT_FILE=$PWD/organizations/peerOrganizations/supplier.example.com/peers/QA2.1.supplier.example.com/tls/ca.crt
    CORE_PEER_MSPCONFIGPATH=$PWD/organizations/peerOrganizations/supplier.example.com/users/Admin@supplier.example.com/msp
    CORE_PEER_ADDRESS=localhost:12051
  elif [ "$ORG" == "Airline" ]; then
    CORE_PEER_LOCALMSPID="AirlineMSP"
    CORE_PEER_TLS_ROOTCERT_FILE=$PWD/organizations/peerOrganizations/airline.example.com/peers/QA3.1.airline.example.com/tls/ca.crt
    CORE_PEER_MSPCONFIGPATH=$PWD/organizations/peerOrganizations/airline.example.com/users/Admin@airline.example.com/msp
    CORE_PEER_ADDRESS=localhost:13051
  else
    echo "================== ERROR !!! ORG Unknown =================="
  fi

  env | grep CORE
}
# # Set environment variables for use in the CLI container
# setGlobalsCLI() {
#   setGlobals $1

#   local USING_ORG=""
#   if [ -z "$OVERRIDE_ORG" ]; then
#     USING_ORG=$1
#   else
#     USING_ORG="${OVERRIDE_ORG}"
#   fi
#   if [ -n "${ORG_NAMES[$USING_ORG]}" ]; then
#     export CORE_PEER_ADDRESS=peer0.${ORG_NAMES[$USING_ORG]}.example.com:$((7051 + ($USING_ORG - 1) * 2000))
#   else
#     errorln "ORG Unknown"
#   fi
# }

setGlobalsCLI() {
  setGlobals $1

  local USING_ORG=""
  local PEER_NAME=""
  local DOMAIN="example.com" # Adjust this to your actual domain if different

  if [ -z "$OVERRIDE_ORG" ]; then
    USING_ORG=$1
  else
    USING_ORG="${OVERRIDE_ORG}"
  fi

  # Determine the peer name based on the organization and peer number
  case $USING_ORG in
    1)
      PEER_NAME="QA1.1.oem"
      ;;
    2)
      PEER_NAME="SW1.1.oem"
      ;;
    3)
      PEER_NAME="QA2.1.supplier"
      ;;
    4)
      PEER_NAME="SW1.2.oem"
      ;;
    5)
      PEER_NAME="SW1.3.oem"
      ;;
    6)
      PEER_NAME="QA3.1.airline"
      ;;
    *)
      echo "Invalid organization number"
      exit 1
      ;;
  esac

  # Assuming all peers are using the same port number for simplicity
  # Adjust the port number as per your network's configuration
  local PORT=7051

  export CORE_PEER_ADDRESS=${PEER_NAME}.${DOMAIN}:${PORT}
}

# parsePeerConnectionParameters $@
# # Helper function that sets the peer connection parameters for a chaincode operation
# parsePeerConnectionParameters() {
#   PEER_CONN_PARMS=()
#   PEERS=""
#   while [ "$#" -gt 0 ]; do
#     setGlobals $1
#     PEER="peer0.${ORG_NAMES[$1]}.example.com"
#     ## Set peer addresses
#     if [ -z "$PEERS" ]; then
#         PEERS="$PEER"
#     else
#         PEERS="$PEERS $PEER"
#     fi
#     PEER_CONN_PARMS=("${PEER_CONN_PARMS[@]}" --peerAddresses $CORE_PEER_ADDRESS)
#     ## Set path to TLS certificate
#     CA=${ORG_CA_FILES[$1]}
#     TLSINFO=(--tlsRootCertFiles "${CA}")
#     PEER_CONN_PARMS=("${PEER_CONN_PARMS[@]}" "${TLSINFO[@]}")
#     # shift by one to get to the next organization
#     shift
#   done
# }

parsePeerConnectionParameters() {
  PEER_CONN_PARMS=()
  PEERS=""
  while [ "$#" -gt 0 ]; do
    setGlobals $1 $2 # Assuming the second parameter is the peer name like QA1.1, SW1.1, etc.
    # Directly use the peer name and organization from the setGlobals function
    PEER="${CORE_PEER_ADDRESS}"

    ## Set peer addresses
    if [ -z "$PEERS" ]; then
        PEERS="$PEER"
    else
        PEERS="$PEERS $PEER"
    fi
    PEER_CONN_PARMS=("${PEER_CONN_PARMS[@]}" --peerAddresses $CORE_PEER_ADDRESS)

    ## Use the CORE_PEER_TLS_ROOTCERT_FILE variable set by setGlobals for the TLS certificate path
    TLSINFO=(--tlsRootCertFiles "${CORE_PEER_TLS_ROOTCERT_FILE}")
    PEER_CONN_PARMS=("${PEER_CONN_PARMS[@]}" "${TLSINFO[@]}")

    # Shift by two to get to the next organization and peer, if applicable
    shift 2
  done
}

verifyResult() {
  if [ $1 -ne 0 ]; then
    fatalln "$2"
  fi
}