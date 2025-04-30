// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IPool} from "aave-v3-core/contracts/interfaces/IPool.sol";
import {DataTypes} from "aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol";
import {IPoolAddressesProvider} from "aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";

abstract contract MockPool is IPool {
    // Mock state variables
    mapping(address => uint256) public supplyBalances;
    mapping(address => uint256) public borrowBalances;
    mapping(address => bool) public collateralEnabled;
    mapping(address => DataTypes.ReserveData) public reserveData;
    mapping(address => mapping(address => uint256)) private _userATokenBalances;
    
    // Mock events
    event Supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode);
    event Withdraw(address asset, uint256 amount, address to);
    event Borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf);
    event Repay(address asset, uint256 amount, uint256 interestRateMode, address onBehalfOf);
    event LiquidationCall(address collateralAsset, address debtAsset, address user, uint256 debtToCover, bool receiveAToken);
    
    // Mock health factor (1e18 = 1.0)
    uint256 public mockHealthFactor = 2e18;
    
    function setMockHealthFactor(uint256 _healthFactor) external {
        mockHealthFactor = _healthFactor;
    }
    
    function supply(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external virtual override {
        supplyBalances[asset] += amount;
        _userATokenBalances[onBehalfOf][asset] += amount;
        emit Supply(asset, amount, onBehalfOf, referralCode);
    }
    
    function supplyWithPermit(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode,
        uint256 deadline,
        uint8 permitV,
        bytes32 permitR,
        bytes32 permitS
    ) external override {
        supplyBalances[asset] += amount;
        emit Supply(asset, amount, onBehalfOf, referralCode);
    }
    
    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external virtual override returns (uint256) {
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
        borrowBalances[asset] += amount;
        emit Borrow(asset, amount, interestRateMode, referralCode, onBehalfOf);
    }
    
    function repay(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        address onBehalfOf
    ) external virtual override returns (uint256) {
        uint256 actualRepay = amount > borrowBalances[asset] ? borrowBalances[asset] : amount;
        borrowBalances[asset] -= actualRepay;
        emit Repay(asset, amount, interestRateMode, onBehalfOf);
        return actualRepay;
    }
    
    function repayWithPermit(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        address onBehalfOf,
        uint256 deadline,
        uint8 permitV,
        bytes32 permitR,
        bytes32 permitS
    ) external override returns (uint256) {
        uint256 actualRepay = amount > borrowBalances[asset] ? borrowBalances[asset] : amount;
        borrowBalances[asset] -= actualRepay;
        emit Repay(asset, amount, interestRateMode, onBehalfOf);
        return actualRepay;
    }
    
    function repayWithATokens(
        address asset,
        uint256 amount,
        uint256 interestRateMode
    ) external override returns (uint256) {
        uint256 actualRepay = amount > borrowBalances[asset] ? borrowBalances[asset] : amount;
        borrowBalances[asset] -= actualRepay;
        emit Repay(asset, amount, interestRateMode, msg.sender);
        return actualRepay;
    }
    
    function swapBorrowRateMode(
        address asset,
        uint256 interestRateMode
    ) external override {
        // Mock implementation - no state changes needed
    }
    
    function rebalanceStableBorrowRate(
        address asset,
        address user
    ) external override {
        // Mock implementation - no state changes needed
    }
    
    function setUserUseReserveAsCollateral(
        address asset,
        bool useAsCollateral
    ) external override {
        collateralEnabled[asset] = useAsCollateral;
    }
    
    function liquidationCall(
        address collateralAsset,
        address debtAsset,
        address user,
        uint256 debtToCover,
        bool receiveAToken
    ) external virtual override {
        emit LiquidationCall(collateralAsset, debtAsset, user, debtToCover, receiveAToken);
    }
    
    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata interestRateModes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    ) external override {
        // Mock implementation - no state changes needed
    }
    
    function flashLoanSimple(
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params,
        uint16 referralCode
    ) external override {
        // Mock implementation - no state changes needed
    }
    
    function getUserAccountData(
        address user
    ) external view override returns (
        uint256 totalCollateralBase,
        uint256 totalDebtBase,
        uint256 availableBorrowsBase,
        uint256 currentLiquidationThreshold,
        uint256 ltv,
        uint256 healthFactor
    ) {
        return (0, 0, type(uint256).max, 0, 0, mockHealthFactor);
    }
    
    function getConfiguration(address asset) external pure override returns (DataTypes.ReserveConfigurationMap memory) {
        return DataTypes.ReserveConfigurationMap(0);
    }
    
    function getUserConfiguration(address user) external pure override returns (DataTypes.UserConfigurationMap memory) {
        return DataTypes.UserConfigurationMap(0);
    }
    
    function getReserveNormalizedIncome(address asset) external pure override returns (uint256) {
        return 0;
    }
    
    function getReserveNormalizedVariableDebt(address asset) external pure override returns (uint256) {
        return 0;
    }
    
    function getReserveData(address asset) external pure virtual override returns (DataTypes.ReserveData memory) {
        return DataTypes.ReserveData({
            configuration: DataTypes.ReserveConfigurationMap(0),
            liquidityIndex: 0,
            currentLiquidityRate: 0,
            variableBorrowIndex: 0,
            currentVariableBorrowRate: 0,
            currentStableBorrowRate: 0,
            lastUpdateTimestamp: 0,
            id: 0,
            aTokenAddress: address(0),
            stableDebtTokenAddress: address(0),
            variableDebtTokenAddress: address(0),
            interestRateStrategyAddress: address(0),
            accruedToTreasury: 0,
            unbacked: 0,
            isolationModeTotalDebt: 0
        });
    }
    
    function getReservesList() external pure override returns (address[] memory) {
        address[] memory reserves = new address[](0);
        return reserves;
    }
    
    function getReserveAddressById(uint16 id) external pure override returns (address) {
        return address(0);
    }
    
    function ADDRESSES_PROVIDER() external pure override returns (IPoolAddressesProvider) {
        return IPoolAddressesProvider(address(0));
    }
    
    function MAX_STABLE_RATE_BORROW_SIZE_PERCENT() external pure override returns (uint256) {
        return 0;
    }
    
    function FLASHLOAN_PREMIUM_TOTAL() external pure override returns (uint128) {
        return 0;
    }
    
    function BRIDGE_PROTOCOL_FEE() external pure override returns (uint256) {
        return 0;
    }
    
    function FLASHLOAN_PREMIUM_TO_PROTOCOL() external pure override returns (uint128) {
        return 0;
    }
    
    function MAX_NUMBER_RESERVES() external pure override returns (uint16) {
        return 0;
    }
    
    function mintUnbacked(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external override {
        // Mock implementation - no state changes needed
    }
    
    function backUnbacked(
        address asset,
        uint256 amount,
        uint256 fee
    ) external override returns (uint256) {
        return 0;
    }
    
    function setReserveData(address asset, DataTypes.ReserveData memory data) external virtual {
        reserveData[asset] = data;
    }
    
    function initReserve(
        address asset,
        address aTokenAddress,
        address stableDebtAddress,
        address variableDebtAddress,
        address interestRateStrategyAddress
    ) external virtual override {
        DataTypes.ReserveData storage reserve = reserveData[asset];
        reserve.aTokenAddress = aTokenAddress;
        reserve.stableDebtTokenAddress = stableDebtAddress;
        reserve.variableDebtTokenAddress = variableDebtAddress;
        reserve.interestRateStrategyAddress = interestRateStrategyAddress;
        reserve.lastUpdateTimestamp = uint40(block.timestamp);
    }
    
    function dropReserve(address asset) external virtual override {
        delete reserveData[asset];
    }
    
    function setReserveInterestRateStrategyAddress(
        address asset,
        address rateStrategyAddress
    ) external virtual override {
        reserveData[asset].interestRateStrategyAddress = rateStrategyAddress;
    }
    
    function setConfiguration(
        address asset,
        DataTypes.ReserveConfigurationMap calldata configuration
    ) external virtual override {
        // Mock implementation - no state changes needed
    }
    
    function finalizeTransfer(
        address asset,
        address from,
        address to,
        uint256 amount,
        uint256 balanceFromBefore,
        uint256 balanceToBefore
    ) external virtual override {
        // Mock implementation - no state changes needed
    }
    
    function updateBridgeProtocolFee(uint256 bridgeProtocolFee) external virtual override {
        // Mock implementation - no state changes needed
    }
    
    function updateFlashloanPremiums(
        uint128 flashLoanPremiumTotal,
        uint128 flashLoanPremiumToProtocol
    ) external virtual override {
        // Mock implementation - no state changes needed
    }
    
    function configureEModeCategory(uint8 id, DataTypes.EModeCategory memory config) external virtual override {
        // Mock implementation - no state changes needed
    }
    
    function getEModeCategoryData(uint8 id) external view virtual override returns (DataTypes.EModeCategory memory) {
        return DataTypes.EModeCategory({
            ltv: 0,
            liquidationThreshold: 0,
            liquidationBonus: 0,
            priceSource: address(0),
            label: ""
        });
    }
    
    function setUserEMode(uint8 categoryId) external virtual override {
        // Mock implementation - no state changes needed
    }
    
    function getUserEMode(address user) external view virtual override returns (uint256) {
        return 0;
    }
    
    function resetIsolationModeTotalDebt(address asset) external virtual override {
        // Mock implementation - no state changes needed
    }
    
    function mintToTreasury(address[] calldata assets) external virtual override {
        // Mock implementation - no state changes needed
    }
    
    function rescueTokens(address token, address to, uint256 amount) external virtual override {
        // Mock implementation - no state changes needed
    }

    function deposit(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external virtual override {
        supplyBalances[asset] += amount;
        emit Supply(asset, amount, onBehalfOf, referralCode);
    }

    function setUserATokenBalance(address user, address asset, uint256 amount) external virtual {
        _userATokenBalances[user][asset] = amount;
    }

    function balanceOf(address asset, address user) external view returns (uint256) {
        return _userATokenBalances[user][asset];
    }

    function getUserATokenBalance(address user, address asset) external view returns (uint256) {
        return _userATokenBalances[user][asset];
    }
}