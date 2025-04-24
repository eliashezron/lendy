// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IPoolAddressesProvider} from "@aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";

/**
 * @title MockPoolAddressesProvider
 * @notice Mock Aave PoolAddressesProvider for testing
 */
contract MockPoolAddressesProvider {
    address public poolAddress;
    
    function setPool(address pool) external {
        poolAddress = pool;
    }
    
    function getPool() external view returns (address) {
        return poolAddress;
    }
} 