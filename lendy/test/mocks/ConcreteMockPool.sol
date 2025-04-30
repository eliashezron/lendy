// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {MockPool} from "./MockPool.sol";
import {DataTypes} from "aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol";

/**
 * @title ConcreteMockPool
 * @notice A concrete implementation of the abstract MockPool contract that can be instantiated
 * @dev This class exists solely to instantiate the abstract MockPool in tests and scripts
 */
contract ConcreteMockPool is MockPool {
    // Define mapping to track balances (even though it exists in MockPool, we need to define it here)
    mapping(address => mapping(address => uint256)) public _userATokenBalances;
    
    // Tracking variables for testing
    address public lastSupplyAsset;
    uint256 public lastSupplyAmount;
    address public lastSupplyOnBehalfOf;
    
    address public lastWithdrawAsset;
    uint256 public lastWithdrawAmount;
    address public lastWithdrawTo;
    
    address public lastBorrowAsset;
    uint256 public lastBorrowAmount;
    uint256 public lastBorrowInterestRateMode;
    address public lastBorrowOnBehalfOf;
    
    address public lastRepayAsset;
    uint256 public lastRepayAmount;
    uint256 public lastRepayInterestRateMode;
    address public lastRepayOnBehalfOf;
    
    address public lastLiquidationCollateralAsset;
    address public lastLiquidationDebtAsset;
    address public lastLiquidationUser;
    uint256 public lastLiquidationDebtToCover;
    bool public lastLiquidationReceiveAToken;
    
    // Make methods public so we can access them in tests
    function getLastSupplyAsset() external view returns (address) {
        return lastSupplyAsset;
    }
    
    function getLastSupplyAmount() external view returns (uint256) {
        return lastSupplyAmount;
    }
    
    function getLastSupplyOnBehalfOf() external view returns (address) {
        return lastSupplyOnBehalfOf;
    }
    
    function getLastWithdrawAsset() external view returns (address) {
        return lastWithdrawAsset;
    }
    
    function getLastWithdrawAmount() external view returns (uint256) {
        return lastWithdrawAmount;
    }
    
    function getLastWithdrawTo() external view returns (address) {
        return lastWithdrawTo;
    }
    
    function getLastBorrowAsset() external view returns (address) {
        return lastBorrowAsset;
    }
    
    function getLastBorrowAmount() external view returns (uint256) {
        return lastBorrowAmount;
    }
    
    function getLastBorrowInterestRateMode() external view returns (uint256) {
        return lastBorrowInterestRateMode;
    }
    
    function getLastBorrowOnBehalfOf() external view returns (address) {
        return lastBorrowOnBehalfOf;
    }
    
    function getLastRepayAsset() external view returns (address) {
        return lastRepayAsset;
    }
    
    function getLastRepayAmount() external view returns (uint256) {
        return lastRepayAmount;
    }
    
    function getLastRepayInterestRateMode() external view returns (uint256) {
        return lastRepayInterestRateMode;
    }
    
    function getLastRepayOnBehalfOf() external view returns (address) {
        return lastRepayOnBehalfOf;
    }
    
    function getLastLiquidationCollateralAsset() external view returns (address) {
        return lastLiquidationCollateralAsset;
    }
    
    function getLastLiquidationDebtAsset() external view returns (address) {
        return lastLiquidationDebtAsset;
    }
    
    function getLastLiquidationUser() external view returns (address) {
        return lastLiquidationUser;
    }
    
    function getLastLiquidationDebtToCover() external view returns (uint256) {
        return lastLiquidationDebtToCover;
    }
    
    function getLastLiquidationReceiveAToken() external view returns (bool) {
        return lastLiquidationReceiveAToken;
    }

    // Override functions to track parameters
    function supply(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external virtual override {
        lastSupplyAsset = asset;
        lastSupplyAmount = amount;
        lastSupplyOnBehalfOf = onBehalfOf;
        
        // Call the parent implementation directly without using super
        supplyBalances[asset] += amount;
        _userATokenBalances[onBehalfOf][asset] += amount;
        emit Supply(asset, amount, onBehalfOf, referralCode);
    }
    
    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external virtual override returns (uint256) {
        lastWithdrawAsset = asset;
        lastWithdrawAmount = amount;
        lastWithdrawTo = to;
        
        // Call the parent implementation directly without using super
        require(_userATokenBalances[msg.sender][asset] >= amount, "Insufficient balance");
        _userATokenBalances[msg.sender][asset] -= amount;
        supplyBalances[asset] -= amount;
        emit Withdraw(asset, amount, to);
        return amount;
    }
    
    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external virtual override {
        lastBorrowAsset = asset;
        lastBorrowAmount = amount;
        lastBorrowInterestRateMode = interestRateMode;
        lastBorrowOnBehalfOf = onBehalfOf;
        
        // Call the parent implementation directly without using super
        borrowBalances[asset] += amount;
        emit Borrow(asset, amount, interestRateMode, referralCode, onBehalfOf);
    }
    
    function repay(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        address onBehalfOf
    ) external virtual override returns (uint256) {
        lastRepayAsset = asset;
        lastRepayAmount = amount;
        lastRepayInterestRateMode = interestRateMode;
        lastRepayOnBehalfOf = onBehalfOf;
        
        // Call the parent implementation directly without using super
        uint256 actualRepay = amount > borrowBalances[asset] ? borrowBalances[asset] : amount;
        borrowBalances[asset] -= actualRepay;
        emit Repay(asset, amount, interestRateMode, onBehalfOf);
        return actualRepay;
    }
    
    function liquidationCall(
        address collateralAsset,
        address debtAsset,
        address user,
        uint256 debtToCover,
        bool receiveAToken
    ) external virtual override {
        lastLiquidationCollateralAsset = collateralAsset;
        lastLiquidationDebtAsset = debtAsset;
        lastLiquidationUser = user;
        lastLiquidationDebtToCover = debtToCover;
        lastLiquidationReceiveAToken = receiveAToken;
        
        // Call the parent implementation directly without using super
        emit LiquidationCall(collateralAsset, debtAsset, user, debtToCover, receiveAToken);
    }
} 