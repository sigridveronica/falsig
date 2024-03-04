#!/bin/bash

function infoln() {
  echo "Info: $1"
}

# Function to create OEM organization
function createOEM() {
  infoln "Enrolling the CA admin for OEM"
  mkdir -p organizations/peerOrganizations/oem.example.com/

  export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/peerOrganizations/oem.example.com/

  set -x
  fabric-ca-client enroll -u https://admin:adminpw@localhost:7054 --caname ca-oem --tls.certfiles "${PWD}/organizations/fabric-ca/oem/ca-cert.pem"
  { set +x; } 2>/dev/null

  echo 'NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/localhost-7054-ca-oem.pem
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/localhost-7054-ca-oem.pem
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/localhost-7054-ca-oem.pem
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/localhost-7054-ca-oem.pem
    OrganizationalUnitIdentifier: orderer' > "${PWD}/organizations/peerOrganizations/oem.example.com/msp/config.yaml"

  # Create and enroll peers for OEM, including explicit handling for signcerts
  for PEER in QA1.1 QA1.2 SW1.1 SW1.2 SW1.3; do
    infoln "Registering and enrolling $PEER for OEM"
    mkdir -p "${PWD}/organizations/peerOrganizations/oem.example.com/peers/${PEER}.oem.example.com"

    fabric-ca-client register --caname ca-oem --id.name $PEER --id.secret ${PEER}pw --id.type peer --tls.certfiles "${PWD}/organizations/fabric-ca/oem/ca-cert.pem"
    fabric-ca-client enroll -u https://${PEER}:${PEER}pw@localhost:7054 --caname ca-oem -M "${PWD}/organizations/peerOrganizations/oem.example.com/peers/${PEER}.oem.example.com/msp" --tls.certfiles "${PWD}/organizations/fabric-ca/oem/ca-cert.pem"

    # Copy the config.yaml
    cp "${PWD}/organizations/peerOrganizations/oem.example.com/msp/config.yaml" "${PWD}/organizations/peerOrganizations/oem.example.com/peers/${PEER}.oem.example.com/msp/config.yaml"

    # Explicit handling for signcerts
    mkdir -p "${PWD}/organizations/peerOrganizations/oem.example.com/peers/${PEER}.oem.example.com/msp/signcerts"
    cp "${PWD}/organizations/peerOrganizations/oem.example.com/peers/${PEER}.oem.example.com/msp/keystore/*_sk" "${PWD}/organizations/peerOrganizations/oem.example.com/peers/${PEER}.oem.example.com/msp/signcerts/${PEER}.oem.example.com-cert.pem"
  done
}

# Function to create Supplier organization
function createSupplier() {
  infoln "Enrolling the CA admin for Supplier"
  mkdir -p organizations/peerOrganizations/supplier.example.com/

  export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/peerOrganizations/supplier.example.com/

  set -x
  fabric-ca-client enroll -u https://admin:adminpw@localhost:8054 --caname ca-supplier --tls.certfiles "${PWD}/organizations/fabric-ca/supplier/ca-cert.pem"
  { set +x; } 2>/dev/null

  echo 'NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/localhost-8054-ca-supplier.pem
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/localhost-8054-ca-supplier.pem
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/localhost-8054-ca-supplier.pem
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/localhost-8054-ca-supplier.pem
    OrganizationalUnitIdentifier: orderer' > "${PWD}/organizations/peerOrganizations/supplier.example.com/msp/config.yaml"

  # Register and enroll peer for Supplier
  infoln "Registering and enrolling peer QA2.1 for Supplier"
  mkdir -p "${PWD}/organizations/peerOrganizations/supplier.example.com/peers/QA2.1.supplier.example.com"

  fabric-ca-client register --caname ca-supplier --id.name QA2.1 --id.secret QA2.1pw --id.type peer --tls.certfiles "${PWD}/organizations/fabric-ca/supplier/ca-cert.pem"
  fabric-ca-client enroll -u https://QA2.1:QA2.1pw@localhost:8054 --caname ca-supplier -M "${PWD}/organizations/peerOrganizations/supplier.example.com/peers/QA2.1.supplier.example.com/msp" --tls.certfiles "${PWD}/organizations/fabric-ca/supplier/ca-cert.pem"

  # Copy the config.yaml
  cp "${PWD}/organizations/peerOrganizations/supplier.example.com/msp/config.yaml" "${PWD}/organizations/peerOrganizations/supplier.example.com/peers/QA2.1.supplier.example.com/msp/config.yaml"

  # Explicit handling for signcerts for Supplier
  mkdir -p "${PWD}/organizations/peerOrganizations/supplier.example.com/peers/QA2.1.supplier.example.com/msp/signcerts"
  cp "${PWD}/organizations/peerOrganizations/supplier.example.com/peers/QA2.1.supplier.example.com/msp/keystore/*_sk" "${PWD}/organizations/peerOrganizations/supplier.example.com/peers/QA2.1.supplier.example.com/msp/signcerts/QA2.1.supplier.example.com-cert.pem"
}

# Function to create Airline organization
function createAirline() {
  infoln "Enrolling the CA admin for Airline"
  mkdir -p organizations/peerOrganizations/airline.example.com/

  export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/peerOrganizations/airline.example.com/

  set -x
  fabric-ca-client enroll -u https://admin:adminpw@localhost:9054 --caname ca-airline --tls.certfiles "${PWD}/organizations/fabric-ca/airline/ca-cert.pem"
  { set +x; } 2>/dev/null

  echo 'NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/localhost-9054-ca-airline.pem
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/localhost-9054-ca-airline.pem
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/localhost-9054-ca-airline.pem
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/localhost-9054-ca-airline.pem
    OrganizationalUnitIdentifier: orderer' > "${PWD}/organizations/peerOrganizations/airline.example.com/msp/config.yaml"

  # Register and enroll peer for Airline
  infoln "Registering and enrolling peer QA3.1 for Airline"
  mkdir -p "${PWD}/organizations/peerOrganizations/airline.example.com/peers/QA3.1.airline.example.com"

  fabric-ca-client register --caname ca-airline --id.name QA3.1 --id.secret QA3.1pw --id.type peer --tls.certfiles "${PWD}/organizations/fabric-ca/airline/ca-cert.pem"
  fabric-ca-client enroll -u https://QA3.1:QA3.1pw@localhost:9054 --caname ca-airline -M "${PWD}/organizations/peerOrganizations/airline.example.com/peers/QA3.1.airline.example.com/msp" --tls.certfiles "${PWD}/organizations/fabric-ca/airline/ca-cert.pem"

  # Copy the config.yaml
  cp "${PWD}/organizations/peerOrganizations/airline.example.com/msp/config.yaml" "${PWD}/organizations/peerOrganizations/airline.example.com/peers/QA3.1.airline.example.com/msp/config.yaml"

  # Explicit handling for signcerts for Airline
  mkdir -p "${PWD}/organizations/peerOrganizations/airline.example.com/peers/QA3.1.airline.example.com/msp/signcerts"
  cp "${PWD}/organizations/peerOrganizations/airline.example.com/peers/QA3.1.airline.example.com/msp/keystore/*_sk" "${PWD}/organizations/peerOrganizations/airline.example.com/peers/QA3.1.airline.example.com/msp/signcerts/QA3.1.airline.example.com-cert.pem"
}



function createOrderer() {
  infoln "Enrolling the CA admin"
  mkdir -p organizations/ordererOrganizations/example.com

  export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/ordererOrganizations/example.com

  set -x
  fabric-ca-client enroll -u https://admin:adminpw@localhost:9054 --caname ca-orderer --tls.certfiles "${PWD}/organizations/fabric-ca/ordererOrg/ca-cert.pem"
  { set +x; } 2>/dev/null

  echo 'NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/localhost-9054-ca-orderer.pem
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/localhost-9054-ca-orderer.pem
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/localhost-9054-ca-orderer.pem
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/localhost-9054-ca-orderer.pem
    OrganizationalUnitIdentifier: orderer' > "${PWD}/organizations/ordererOrganizations/example.com/msp/config.yaml"

  # Since the CA serves as both the organization CA and TLS CA, copy the org's root cert that was generated by CA startup into the org level ca and tlsca directories

  # Copy orderer org's CA cert to orderer org's /msp/tlscacerts directory (for use in the channel MSP definition)
  mkdir -p "${PWD}/organizations/ordererOrganizations/example.com/msp/tlscacerts"
  cp "${PWD}/organizations/fabric-ca/ordererOrg/ca-cert.pem" "${PWD}/organizations/ordererOrganizations/example.com/msp/tlscacerts/tlsca.example.com-cert.pem"

  # Copy orderer org's CA cert to orderer org's /tlsca directory (for use by clients)
  mkdir -p "${PWD}/organizations/ordererOrganizations/example.com/tlsca"
  cp "${PWD}/organizations/fabric-ca/ordererOrg/ca-cert.pem" "${PWD}/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem"

  infoln "Registering orderer"
  set -x
  fabric-ca-client register --caname ca-orderer --id.name orderer --id.secret ordererpw --id.type orderer --tls.certfiles "${PWD}/organizations/fabric-ca/ordererOrg/ca-cert.pem"
  { set +x; } 2>/dev/null

  infoln "Registering the orderer admin"
  set -x
  fabric-ca-client register --caname ca-orderer --id.name ordererAdmin --id.secret ordererAdminpw --id.type admin --tls.certfiles "${PWD}/organizations/fabric-ca/ordererOrg/ca-cert.pem"
  { set +x; } 2>/dev/null

  infoln "Generating the orderer msp"
  set -x
  fabric-ca-client enroll -u https://orderer:ordererpw@localhost:9054 --caname ca-orderer -M "${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp" --tls.certfiles "${PWD}/organizations/fabric-ca/ordererOrg/ca-cert.pem"
  { set +x; } 2>/dev/null

  cp "${PWD}/organizations/ordererOrganizations/example.com/msp/config.yaml" "${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/config.yaml"

  infoln "Generating the orderer-tls certificates, use --csr.hosts to specify Subject Alternative Names"
  set -x
  fabric-ca-client enroll -u https://orderer:ordererpw@localhost:9054 --caname ca-orderer -M "${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls" --enrollment.profile tls --csr.hosts orderer.example.com --csr.hosts localhost --tls.certfiles "${PWD}/organizations/fabric-ca/ordererOrg/ca-cert.pem"
  { set +x; } 2>/dev/null

  # Copy the tls CA cert, server cert, server keystore to well known file names in the orderer's tls directory that are referenced by orderer startup config
  cp "${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/tlscacerts/"* "${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt"
  cp "${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/signcerts/"* "${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.crt"
  cp "${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/keystore/"* "${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.key"

  # Copy orderer org's CA cert to orderer's /msp/tlscacerts directory (for use in the orderer MSP definition)
  mkdir -p "${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts"
  cp "${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/tlscacerts/"* "${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem"

  infoln "Generating the admin msp"
  set -x
  fabric-ca-client enroll -u https://ordererAdmin:ordererAdminpw@localhost:9054 --caname ca-orderer -M "${PWD}/organizations/ordererOrganizations/example.com/users/Admin@example.com/msp" --tls.certfiles "${PWD}/organizations/fabric-ca/ordererOrg/ca-cert.pem"
  { set +x; } 2>/dev/null

  cp "${PWD}/organizations/ordererOrganizations/example.com/msp/config.yaml" "${PWD}/organizations/ordererOrganizations/example.com/users/Admin@example.com/msp/config.yaml"
}


# Main script execution
createOEM
createSupplier
createAirline


