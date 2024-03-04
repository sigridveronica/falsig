#!/bin/bash

# Exit on first error
set -e

# Import environment variables from the test network scripts
. ./scripts/envVar.sh

# Set environment variables for your organization
setGlobals 1 'oem'

# Invoke chaincode
peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls --cafile $ORDERER_CA -C mychannel -n oemContract --peerAddresses localhost:7051 --tlsRootCertFiles $PEER0_ORG1_CA -c '{"function":"CreateActivity","Args":["arg1","arg2"]}'