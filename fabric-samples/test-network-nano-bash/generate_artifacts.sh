#!/bin/bash

# Function to generate channel genesis block
generateGenesisBlock() {
    CHANNEL_NAME=$1
    PROFILE_NAME=$2
    echo "Generating genesis block for channel '$CHANNEL_NAME' with profile '$PROFILE_NAME'"
    configtxgen -profile ${PROFILE_NAME} -outputBlock ./channel-artifacts/${CHANNEL_NAME}.block -channelID ${CHANNEL_NAME}
    if [ "$?" -ne 0 ]; then
        echo "Failed to generate channel genesis block for ${CHANNEL_NAME}"
        exit 1
    fi
}

# Function to generate anchor peer transactions
generateAnchorPeerTx() {
    CHANNEL_NAME=$1
    PROFILE_NAME=$2
    declare -a ORGS=("${!3}")
    for ORG in "${ORGS[@]}"; do
        echo "Generating anchor peer transaction for ${ORG} in channel '${CHANNEL_NAME}'"
        configtxgen -profile ${PROFILE_NAME} -outputAnchorPeersUpdate ./channel-artifacts/${CHANNEL_NAME}${ORG}Anchors.tx -channelID ${CHANNEL_NAME} -asOrg ${ORG}
        if [ "$?" -ne 0 ]; then
            echo "Failed to generate anchor peer transaction for ${ORG} in channel ${CHANNEL_NAME}"
            exit 1
        fi
    done
}

# Check for the correct number of arguments
if [ "$#" -lt 3 ]; then
    echo "Usage: $0 <ChannelName> <ProfileName> <Org1> <Org2> ..."
    echo "Example: $0 mychannel TwoOrgsChannel Org1MSP Org2MSP"
    exit 1
fi

CHANNEL_NAME=$1
PROFILE_NAME=$2

# Collect all organizations into an array
ORGS=("${@:3}")

# Directory where to store generated artifacts
ARTIFACTS_DIR="./channel-artifacts"
mkdir -p ${ARTIFACTS_DIR}

# Generate channel genesis block
generateGenesisBlock ${CHANNEL_NAME} ${PROFILE_NAME}

# Generate anchor peer transactions for all organizations
generateAnchorPeerTx ${CHANNEL_NAME} ${PROFILE_NAME} ORGS[@]

echo "Artifacts for channel '${CHANNEL_NAME}' have been generated successfully."