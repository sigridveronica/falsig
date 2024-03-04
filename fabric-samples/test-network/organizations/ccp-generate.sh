#!/bin/bash

function one_line_pem {
    echo "`awk 'NF {sub(/\\n/, ""); printf "%s\\\\\\\n",$0;}' $1`"
}

function json_ccp {
    local PP=$(one_line_pem $4)
    local CP=$(one_line_pem $5)
    sed -e "s/\${ORG}/$1/" \
        -e "s/\${P0PORT}/$2/" \
        -e "s/\${CAPORT}/$3/" \
        -e "s#\${PEERPEM}#$PP#" \
        -e "s#\${CAPEM}#$CP#" \
        organizations/ccp-template.json
}

function yaml_ccp {
    local PP=$(one_line_pem $4)
    local CP=$(one_line_pem $5)
    sed -e "s/\${ORG}/$1/" \
        -e "s/\${P0PORT}/$2/" \
        -e "s/\${CAPORT}/$3/" \
        -e "s#\${PEERPEM}#$PP#" \
        -e "s#\${CAPEM}#$CP#" \
        organizations/ccp-template.yaml | sed -e $'s/\\\\n/\\\n          /g'
}

# OEM Configuration
ORG=OEM
P0PORT=7051 # Example port, adjust as needed
CAPORT=7054 # Example port, adjust as needed
PEERPEM=organizations/peerOrganizations/oem.example.com/tlsca/tlsca.oem.example.com-cert.pem
CAPEM=organizations/peerOrganizations/oem.example.com/ca/ca.oem.example.com-cert.pem

echo "$(json_ccp $ORG $P0PORT $CAPORT $PEERPEM $CAPEM)" > organizations/peerOrganizations/oem.example.com/connection-oem.json
echo "$(yaml_ccp $ORG $P0PORT $CAPORT $PEERPEM $CAPEM)" > organizations/peerOrganizations/oem.example.com/connection-oem.yaml

# Airline Configuration
ORG=Airline
P0PORT=9051 # Example port, adjust as needed
CAPORT=8054 # Example port, adjust as needed
PEERPEM=organizations/peerOrganizations/airline.example.com/tlsca/tlsca.airline.example.com-cert.pem
CAPEM=organizations/peerOrganizations/airline.example.com/ca/ca.airline.example.com-cert.pem

echo "$(json_ccp $ORG $P0PORT $CAPORT $PEERPEM $CAPEM)" > organizations/peerOrganizations/airline.example.com/connection-airline.json
echo "$(yaml_ccp $ORG $P0PORT $CAPORT $PEERPEM $CAPEM)" > organizations/peerOrganizations/airline.example.com/connection-airline.yaml

# Supplier Configuration
ORG=Supplier
P0PORT=10051 # Example port, adjust as needed
CAPORT=10054 # Example port, adjust as needed
PEERPEM=organizations/peerOrganizations/supplier.example.com/tlsca/tlsca.supplier.example.com-cert.pem
CAPEM=organizations/peerOrganizations/supplier.example.com/ca/ca.supplier.example.com-cert.pem

echo "$(json_ccp $ORG $P0PORT $CAPORT $PEERPEM $CAPEM)" > organizations/peerOrganizations/supplier.example.com/connection-supplier.json
echo "$(yaml_ccp $ORG $P0PORT $CAPORT $PEERPEM $CAPEM)" > organizations/peerOrganizations/supplier.example.com/connection-supplier.yaml