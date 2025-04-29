#!/bin/bash

# Set chain ID for Celo mainnet
export CHAIN_ID=42220

# Get network argument
if [ "$1" ]; then
  NETWORK="$1"
else
  NETWORK="celo_mainnet"
fi

# Get script type argument
if [ "$2" ]; then
  SCRIPT_TYPE="$2"
else
  SCRIPT_TYPE="deploy"
fi

# Clean up function to delete temporary files
cleanup() {
  rm -f script/CustomInteraction.s.sol
  echo "Cleanup complete."
}

# Register the cleanup function
trap cleanup EXIT

if [ "$SCRIPT_TYPE" == "deploy" ]; then
  echo "Deploying Lendy Protocol to $NETWORK..."
  
  # Run the deployment script
  if [ "$NETWORK" == "celo_mainnet" ]; then
    # Real deployment to mainnet
    echo "REAL MAINNET DEPLOYMENT - Ensure you have reviewed the code carefully!"
    forge script script/Deploy.s.sol:DeployCeloMainnet --rpc-url https://forno.celo.org --broadcast --legacy -vvv
  else
    # For testing on testnets
    echo "Testing deployment to $NETWORK..."
    forge script script/Deploy.s.sol:DeployCeloMainnet --rpc-url https://forno.celo.org --broadcast --legacy -vvv
  fi
  
  # Echo addresses for later use
  echo "Deployment complete! Copy the following addresses for later use:"
  echo "LENDY_PROTOCOL=<address>"
  echo "LENDY_POSITION_MANAGER=<address>"
  
elif [ "$SCRIPT_TYPE" == "interact" ]; then
  echo "Interacting with deployed contracts on $NETWORK..."
  
  # These addresses should be updated to your actual deployed addresses
  export LENDY_PROTOCOL=0x80A076F99963C3399F12FE114507b54c13f28510
  export LENDY_POSITION_MANAGER=0x5a34479FfcAAB729071725515773E68742d43672
  
  # Create a temporary file with the deployed addresses
  cat > script/CustomInteraction.s.sol << EOL
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {InteractCeloMainnet} from "./InteractCeloMainnet.s.sol";

contract CustomInteraction is InteractCeloMainnet {
    constructor() InteractCeloMainnet() {
        // Set the addresses of your deployed contracts
        LENDY_PROTOCOL = 0x80A076F99963C3399F12FE114507b54c13f28510;
        LENDY_POSITION_MANAGER = 0x5a34479FfcAAB729071725515773E68742d43672;
    }
    
    function setUp() public override {
        super.setUp();
    }
}
EOL

  # Wait for contracts to be fully deployed before running interaction script
  echo "Waiting for contracts to be fully indexed..."
  sleep 5
  
  # Get the test function to run
  if [ "$3" ]; then
    TEST_FUNCTION="$3"
  else
    TEST_FUNCTION="all"
  fi
  
  echo "IMPORTANT NOTES BEFORE TESTING:"
  echo "1. Make sure you have at least 0.1 USDT in your wallet for testing"
  echo "2. The Position Manager operations currently fail with AAVE error 43"
  echo "3. For best results, use the direct functions: supply, collateral, borrow"
  echo "4. The 'direct' test function gives the most reliable results using AAVE directly"
  echo ""
  echo "Running test function: $TEST_FUNCTION"
  echo "Available test functions: supply, collateral, position, borrow, direct, all"
  echo ""
  
  # Clean build artifacts first
  echo "Cleaning build artifacts..."
  forge clean
  
  # Run the interaction script
  if [ "$NETWORK" == "celo_mainnet" ]; then
    export TEST_FUNCTION=$TEST_FUNCTION
    forge script script/InteractCeloMainnet.s.sol:InteractCeloMainnet --rpc-url https://forno.celo.org --broadcast -vvv
  else
    # Testing on other networks
    echo "Testing interaction with contracts on $NETWORK..."
    export TEST_FUNCTION=$TEST_FUNCTION
    forge script script/InteractCeloMainnet.s.sol:InteractCeloMainnet --rpc-url https://forno.celo.org --broadcast -vvv
  fi
else
  echo "Unknown script type: $SCRIPT_TYPE"
  echo "Usage: ./deploy.sh [network] [script_type] [test_function]"
  echo "  network: celo_mainnet (default)"
  echo "  script_type: deploy (default) or interact"
  echo "  test_function: supply, collateral, position, borrow, direct, all (default)"
  exit 1
fi

echo "Script has completed!" 