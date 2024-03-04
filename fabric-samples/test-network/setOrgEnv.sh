#!/bin/bash
#
# SPDX-License-Identifier: Apache-2.0

# default to using OEM and peer QA1.1
ORG=${1:-OEM}
PEER=${2:-QA1.1}

# Exit on first error, print all commands.
set -e
set -o pipefail

# Where am I?
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

# Define CA certificates for each organization
ORDERER_CA=${DIR}/test-network/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem
PEER_QA1_1_CA=${DIR}/test-network/organizations/peerOrganizations/oem.example.com/tlsca/tlsca.oem.example.com-cert.pem
PEER_QA2_1_CA=${DIR}/test-network/organizations/peerOrganizations/supplier.example.com/tlsca/tlsca.supplier.example.com-cert.pem
PEER_QA3_1_CA=${DIR}/test-network/organizations/peerOrganizations/airline.example.com/tlsca/tlsca.airline.example.com-cert.pem

# Convert ORG and PEER to lowercase using tr for compatibility
org_lower=$(echo "$ORG" | tr '[:upper:]' '[:lower:]')
peer_lower=$(echo "$PEER" | tr '[:upper:]' '[:lower:]')

# Set environment variables based on organization and peer
if [[ $org_lower == "oem" ]]; then
   CORE_PEER_LOCALMSPID=OEMMSP
   CORE_PEER_MSPCONFIGPATH=${DIR}/test-network/organizations/peerOrganizations/oem.example.com/users/Admin@oem.example.com/msp
   # Dynamically set the CORE_PEER_TLS_ROOTCERT_FILE based on the peer
   case $peer_lower in
     "qa1.1")
       CORE_PEER_ADDRESS=localhost:7051
       CORE_PEER_TLS_ROOTCERT_FILE=${DIR}/test-network/organizations/peerOrganizations/oem.example.com/peers/QA1.1.oem.example.com/tls/ca.crt
       ;;
     "qa1.2")
       CORE_PEER_ADDRESS=localhost:7052
       CORE_PEER_TLS_ROOTCERT_FILE=${DIR}/test-network/organizations/peerOrganizations/oem.example.com/peers/QA1.2.oem.example.com/tls/ca.crt
       ;;
     "sw1.1")
       CORE_PEER_ADDRESS=localhost:7053
       CORE_PEER_TLS_ROOTCERT_FILE=${DIR}/test-network/organizations/peerOrganizations/oem.example.com/peers/SW1.1.oem.example.com/tls/ca.crt
       ;;
     "sw1.2")
       CORE_PEER_ADDRESS=localhost:7054
       CORE_PEER_TLS_ROOTCERT_FILE=${DIR}/test-network/organizations/peerOrganizations/oem.example.com/peers/SW1.2.oem.example.com/tls/ca.crt
       ;;
     "sw1.3")
       CORE_PEER_ADDRESS=localhost:7055
       CORE_PEER_TLS_ROOTCERT_FILE=${DIR}/test-network/organizations/peerOrganizations/oem.example.com/peers/SW1.3.oem.example.com/tls/ca.crt
       ;;
     *)
       echo "Unknown peer $PEER for organization $ORG"
       exit 2
       ;;
   esac
   #CORE_PEER_TLS_ROOTCERT_FILE=${PEER_QA1_1_CA}

elif [[ $org_lower == "supplier" ]]; then
   CORE_PEER_LOCALMSPID=SupplierMSP
   CORE_PEER_MSPCONFIGPATH=${DIR}/test-network/organizations/peerOrganizations/supplier.example.com/users/Admin@supplier.example.com/msp
   CORE_PEER_ADDRESS=localhost:8051 # Assuming QA2.1 is running on this port
   CORE_PEER_TLS_ROOTCERT_FILE=${PEER_QA2_1_CA}

elif [[ $org_lower == "airline" ]]; then
   CORE_PEER_LOCALMSPID=AirlineMSP
   CORE_PEER_MSPCONFIGPATH=${DIR}/test-network/organizations/peerOrganizations/airline.example.com/users/Admin@airline.example.com/msp
   CORE_PEER_ADDRESS=localhost:9051 # Assuming QA3.1 is running on this port
   CORE_PEER_TLS_ROOTCERT_FILE=${PEER_QA3_1_CA}

else
   echo "Unknown organization \"$ORG\""
   exit 1
fi

# Output the variables that need to be set
echo "CORE_PEER_TLS_ENABLED=true"
echo "ORDERER_CA=${ORDERER_CA}"
echo "PEER_QA1_1_CA=${PEER_QA1_1_CA}"
echo "PEER_QA2_1_CA=${PEER_QA2_1_CA}"
echo "PEER_QA3_1_CA=${PEER_QA3_1_CA}"

echo "CORE_PEER_MSPCONFIGPATH=${CORE_PEER_MSPCONFIGPATH}"
echo "CORE_PEER_ADDRESS=${CORE_PEER_ADDRESS}"
echo "CORE_PEER_TLS_ROOTCERT_FILE=${CORE_PEER_TLS_ROOTCERT_FILE}"

echo "CORE_PEER_LOCALMSPID=${CORE_PEER_LOCALMSPID}"