#!/bin/bash

# imports  
. scripts/envVar.sh
. scripts/utils.sh


CHANNEL_NAME="$1"
DELAY="$2"
MAX_RETRY="$3"
VERBOSE="$4"
BFT="$5"
: ${CHANNEL_NAME:="mychannel"}
: ${DELAY:="3"}
: ${MAX_RETRY:="5"}
: ${VERBOSE:="false"}
: ${BFT:=0}

: ${CONTAINER_CLI:="docker"}
if command -v ${CONTAINER_CLI}-compose > /dev/null 2>&1; then
    : ${CONTAINER_CLI_COMPOSE:="${CONTAINER_CLI}-compose"}
else
    : ${CONTAINER_CLI_COMPOSE:="${CONTAINER_CLI} compose"}
fi
infoln "Using ${CONTAINER_CLI} and ${CONTAINER_CLI_COMPOSE}"

if [ ! -d "channel-artifacts" ]; then
	mkdir channel-artifacts
fi

createChannelGenesisBlock() {
  setGlobals 1
  which configtxgen
  if [ "$?" -ne 0 ]; then
    fatalln "configtxgen tool not found."
  fi
  local channel_name=$1
  local profile_name="" # Initialize profile_name as an empty string

  # Convert channel_name to uppercase for comparison
  local upper_channel_name=$(echo "$channel_name" | tr '[:lower:]' '[:upper:]')

  set -x

  # Determine the profile name based on the channel name
  case "$upper_channel_name" in
    "OEMCHANNEL")
      profile_name="OEMChannel"
      ;;
    "AIRLINEOEMCHANNEL")
      profile_name="AirlineOEMChannel"
      ;;
    "SUPPLIEROEMCHANNEL")
      profile_name="SupplierOEMChannel"
      ;;
    *)
      fatalln "Unknown channel name: $channel_name"
      ;;
  esac

  # Generate the channel configuration block using the determined profile
  configtxgen -profile $profile_name -outputBlock ./channel-artifacts/${channel_name}.block -channelID $channel_name
  res=$?
  { set +x; } 2>/dev/null
  verifyResult $res "Failed to generate channel configuration transaction..."
}
createChannel() {
	# Poll in case the raft leader is not set yet
	local rc=1
	local COUNTER=1
	local bft_true=$1
	infoln "Adding orderers"
	while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ] ; do
		sleep $DELAY
		set -x
    . scripts/orderer.sh ${CHANNEL_NAME}> /dev/null 2>&1
    if [ $bft_true -eq 1 ]; then
      . scripts/orderer2.sh ${CHANNEL_NAME}> /dev/null 2>&1
      . scripts/orderer3.sh ${CHANNEL_NAME}> /dev/null 2>&1
      . scripts/orderer4.sh ${CHANNEL_NAME}> /dev/null 2>&1
    fi
		res=$?
		{ set +x; } 2>/dev/null
		let rc=$res
		COUNTER=$(expr $COUNTER + 1)
	done
	cat log.txt
	verifyResult $res "Channel creation failed"
}

# joinChannel ORG
joinChannel() {
  ORG=$1
  FABRIC_CFG_PATH=$PWD/../config/
  setGlobals $ORG
	local rc=1
	local COUNTER=1
	## Sometimes Join takes time, hence retry
	while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ] ; do
    sleep $DELAY
    set -x
    peer channel join -b $BLOCKFILE >&log.txt
    res=$?
    { set +x; } 2>/dev/null
		let rc=$res
		COUNTER=$(expr $COUNTER + 1)
	done
	cat log.txt
	verifyResult $res "After $MAX_RETRY attempts, peer0.org${ORG} has failed to join channel '$CHANNEL_NAME' "
}

setAnchorPeer() {
  ORG=$1
  ${CONTAINER_CLI} exec cli ./scripts/setAnchorPeer.sh $ORG $CHANNEL_NAME 
}


## User attempts to use BFT orderer in Fabric network with CA
if [ $BFT -eq 1 ] && [ -d "organizations/fabric-ca/ordererOrg/msp" ]; then
  fatalln "Fabric network seems to be using CA. This sample does not yet support the use of consensus type BFT and CA together."
fi

## Create channel genesis block
FABRIC_CFG_PATH=$PWD/../config/
BLOCKFILE="./channel-artifacts/${CHANNEL_NAME}.block"

infoln "Generating channel genesis block '${CHANNEL_NAME}.block'"
FABRIC_CFG_PATH=${PWD}/configtx
if [ $BFT -eq 1 ]; then
  FABRIC_CFG_PATH=${PWD}/bft-config
fi

echo "Channel name before createChannelGenesisBlock: ${CHANNEL_NAME}"
createChannelGenesisBlock $CHANNEL_NAME

## Create channel
infoln "Creating channel ${CHANNEL_NAME}"
createChannel $BFT
successln "Channel '$CHANNEL_NAME' created"

## Join all the peers to the channel
infoln "Joining org1 peer to the channel..."
joinChannel 1
infoln "Joining org2 peer to the channel..."
joinChannel 2

## Set the anchor peers for each org in the channel
infoln "Setting anchor peer for org1..."
setAnchorPeer 1
infoln "Setting anchor peer for org2..."
setAnchorPeer 2

successln "Channel '$CHANNEL_NAME' joined"
