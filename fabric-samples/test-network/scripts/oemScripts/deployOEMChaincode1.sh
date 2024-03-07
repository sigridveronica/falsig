#!/bin/bash

# Exit on first error
set -e

# Import environment variables from the test network scripts
. ./scripts/envVar.sh

# Package the chaincode
peer lifecycle chaincode package oemContract.tar.gz --path ./chaincode/oemContract/ --lang golang --label oemContract_1

# Install the chaincode on peer0.org1
setGlobals 1 'oem'
peer lifecycle chaincode install oemContract.tar.gz

# Approve the chaincode for your org
peer lifecycle chaincode approveformyorg -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --channelID mychannel --name oemContract --version 1.0 --package-id oemContract_1:hash --sequence 1 --tls --cafile $ORDERER_CA

# Check if ready to commit
peer lifecycle chaincode checkcommitreadiness --channelID mychannel --name oemContract --version 1.0 --sequence 1 --tls --cafile $ORDERER_CA --output json

# Commit the chaincode (requires approval from all orgs in the channel)
peer lifecycle chaincode commit -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --channelID mychannel --name oemContract --version 1.0 --sequence 1 --tls --cafile $ORDERER_CA --peerAddresses localhost:7051 --tlsRootCertFiles $PEER0_ORG1_CA