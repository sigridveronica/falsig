#!/bin/bash

# Exit on first error
set -e

# Import environment variables from the test network scripts
. ./scripts/envVar.sh

# Function to package the chaincode
packageChaincode() {
  peer lifecycle chaincode package oemContract.tar.gz --path ./chaincode/oemContract/ --lang golang --label oemContract_1
}

# Function to install chaincode on a peer
installChaincode() {
  ORG=$1
  PEER=$2
  setGlobals $PEER $ORG
  peer lifecycle chaincode install oemContract.tar.gz
}

# Function to approve chaincode for org
approveChaincodeForOrg() {
  ORG=$1
  PEER=$2
  CHANNEL=$3
  setGlobals $PEER $ORG
  peer lifecycle chaincode approveformyorg -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --channelID $CHANNEL --name oemContract --version 1.0 --package-id oemContract_1:hash --sequence 1 --tls --cafile $ORDERER_CA
}

# Package the chaincode
packageChaincode

# Install chaincode on all OEM peers
installChaincode "oem" "QA1.1"
installChaincode "oem" "QA1.2"
installChaincode "oem" "SW1.1"
installChaincode "oem" "SW1.2"
installChaincode "oem" "SW1.3"

# Install chaincode on Supplier and Airline peers
installChaincode "supplier" "QA2.1"
installChaincode "airline" "QA3.1"

# Approve chaincode for OEM channel
approveChaincodeForOrg "oem" "QA1.1" "oemchannel"
approveChaincodeForOrg "oem" "QA1.2" "oemchannel"
approveChaincodeForOrg "oem" "SW1.1" "oemchannel"
approveChaincodeForOrg "oem" "SW1.2" "oemchannel"
approveChaincodeForOrg "oem" "SW1.3" "oemchannel"

# Approve chaincode for Airline-OEM channel
approveChaincodeForOrg "oem" "QA1.2" "airline-oemchannel"
approveChaincodeForOrg "airline" "QA3.1" "airline-oemchannel"

# Approve chaincode for Supplier-OEM channel
approveChaincodeForOrg "supplier" "QA2.1" "supplier-oemchannel"
approveChaincodeForOrg "oem" "QA1.2" "supplier-oemchannel"

# Assuming the checkcommitreadiness and commit steps are similar across channels, 
# you would repeat the checkcommitreadiness for each channel as needed, 
# and then commit the chaincode to each channel, specifying the relevant peers for each commit.

# Example for committing to the OEM channel (adjust peerAddresses and tlsRootCertFiles as needed)
peer lifecycle chaincode commit -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --channelID oemchannel --name oemContract --version 1.0 --sequence 1 --tls --cafile $ORDERER_CA --peerAddresses localhost:7051 --tlsRootCertFiles $PEER0_OEM_CA