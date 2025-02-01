#!/bin/bash

source .env

if [ "$1" = "holesky" ]; then
  NETWORK=$HOLESKY_API
  CHAIN_ID=17000
elif [ "$1" = "sepolia" ]; then
  NETWORK=$SEPOLIA_API
  CHAIN_ID=11155111
elif [ "$1" = "mainnet" ]; then
  NETWORK=$MAINNET_API
  CHAIN_ID=1
else
  echo "Usage: ./deploy.sh [network]"
  exit 1
fi

forge script script/LaunchpadFactory.s.sol:LaunchpadDeployerScript \
  --rpc-url $NETWORK \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --chain-id $CHAIN_ID