// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Interface for the AAVE Pool
interface IPool {
    struct ReserveConfigurationMap {
        uint256 data;
    }

    struct ReserveData {
        ReserveConfigurationMap configuration;
        uint128 liquidityIndex;
        uint128 currentLiquidityRate;
        uint128 variableBorrowIndex;
        uint128 currentVariableBorrowRate;
        uint128 currentStableBorrowRate;
        uint40 lastUpdateTimestamp;
        uint16 id;
        address aTokenAddress;
        address stableDebtTokenAddress;
        address variableDebtTokenAddress;
        address interestRateStrategyAddress;
        uint128 accruedToTreasury;
        uint128 unbacked;
        uint128 isolationModeTotalDebt;
    }

    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
    function borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf) external;
    function repay(address asset, uint256 amount, uint256 interestRateMode, address onBehalfOf) external returns (uint256);
    function getUserAccountData(address user) external view returns (
        uint256 totalCollateralBase,
        uint256 totalDebtBase,
        uint256 availableBorrowsBase,
        uint256 currentLiquidationThreshold,
        uint256 ltv,
        uint256 healthFactor
    );
    function setUserUseReserveAsCollateral(address asset, bool useAsCollateral) external;
    function getReserveData(address asset) external view returns (ReserveData memory);
}

// Interface for faucet (for testing on testnets)
interface IFaucet {
    function mint(address token, uint256 amount) external;
}

/**
 * @title DirectAaveTest
 * @notice Script to directly interact with AAVE pool on Celo
 */
contract DirectAaveTest is Script {
    // AAVE V3 Pool on Celo mainnet
    address public constant AAVE_POOL = 0x3E59A31363E2ad014dcbc521c4a0d5757d9f3402;
    
    // Celo mainnet token addresses
    address public constant USDC = 0xcebA9300f2b948710d2653dD7B07f33A8B32118C;
    address public constant USDT = 0x48065fbBE25f71C9282ddf5e1cD6D6A887483D5e;
    
    // Faucet address for testnets (not available on mainnet)
    address public constant FAUCET_ADDRESS = address(0); // Set a proper address if testing on testnet
    
    address public user;
    uint256 public userPrivateKey;
    
    // Error codes from AAVE
    mapping(uint256 => string) aaveErrors;

    function setUp() public {
        // Process private key from CELO_MAINNET_PRIVATE_KEY
        try vm.envUint("CELO_MAINNET_PRIVATE_KEY") returns (uint256 pk) {
            userPrivateKey = pk;
        } catch {
            // Try to read as a hex string with 0x prefix
            string memory pkString = vm.envString("CELO_MAINNET_PRIVATE_KEY");
            if (bytes(pkString).length > 0 && bytes(pkString)[0] == "0" && bytes(pkString)[1] == "x") {
                userPrivateKey = vm.parseUint(pkString);
            } else {
                // If no 0x prefix, try adding it
                userPrivateKey = vm.parseUint(string(abi.encodePacked("0x", pkString)));
            }
        }
        
        user = vm.addr(userPrivateKey);
        
        // Initialize AAVE error codes for better error reporting
        aaveErrors[1] = "CALLER_NOT_POOL_ADMIN";
        aaveErrors[2] = "CALLER_NOT_EMERGENCY_ADMIN";
        aaveErrors[3] = "CALLER_NOT_POOL_OR_EMERGENCY_ADMIN";
        aaveErrors[4] = "CALLER_NOT_RISK_OR_POOL_ADMIN";
        aaveErrors[5] = "CALLER_NOT_ASSET_LISTING_OR_POOL_ADMIN";
        aaveErrors[6] = "CALLER_NOT_BRIDGE";
        aaveErrors[7] = "ADDRESSES_PROVIDER_NOT_REGISTERED";
        aaveErrors[8] = "INVALID_ADDRESSES_PROVIDER_ID";
        aaveErrors[9] = "NOT_CONTRACT";
        aaveErrors[10] = "CALLER_NOT_POOL_CONFIGURATOR";
        aaveErrors[11] = "CALLER_NOT_ATOKEN";
        aaveErrors[12] = "INVALID_ADDRESSES_PROVIDER";
        aaveErrors[13] = "INVALID_FLASHLOAN_EXECUTOR_RETURN";
        aaveErrors[14] = "RESERVE_ALREADY_ADDED";
        aaveErrors[15] = "NO_MORE_RESERVES_ALLOWED";
        aaveErrors[16] = "EMODE_CATEGORY_RESERVED";
        aaveErrors[17] = "INVALID_EMODE_CATEGORY_ASSIGNMENT";
        aaveErrors[18] = "RESERVE_LIQUIDITY_NOT_ZERO";
        aaveErrors[19] = "FLASHLOAN_PREMIUM_INVALID";
        aaveErrors[20] = "INVALID_RESERVE_PARAMS";
        aaveErrors[21] = "INVALID_EMODE_CATEGORY_PARAMS";
        aaveErrors[22] = "BRIDGE_PROTOCOL_FEE_INVALID";
        aaveErrors[23] = "CALLER_MUST_BE_POOL";
        aaveErrors[24] = "INVALID_MINT_AMOUNT";
        aaveErrors[25] = "INVALID_BURN_AMOUNT";
        aaveErrors[26] = "INVALID_AMOUNT";
        aaveErrors[27] = "RESERVE_INACTIVE";
        aaveErrors[28] = "RESERVE_FROZEN";
        aaveErrors[29] = "RESERVE_PAUSED";
        aaveErrors[30] = "BORROWING_NOT_ENABLED";
        aaveErrors[31] = "STABLE_BORROWING_NOT_ENABLED";
        aaveErrors[32] = "COLLATERAL_BALANCE_IS_ZERO";
        aaveErrors[33] = "HEALTH_FACTOR_LOWER_THAN_LIQUIDATION_THRESHOLD";
        aaveErrors[34] = "COLLATERAL_CANNOT_COVER_NEW_BORROW";
        aaveErrors[35] = "COLLATERAL_SAME_AS_BORROWING_CURRENCY";
        aaveErrors[36] = "AMOUNT_BIGGER_THAN_MAX_LOAN_SIZE_STABLE";
        aaveErrors[37] = "NO_DEBT_OF_SELECTED_TYPE";
        aaveErrors[38] = "NO_EXPLICIT_AMOUNT_TO_REPAY_ON_BEHALF";
        aaveErrors[39] = "NO_OUTSTANDING_STABLE_DEBT";
        aaveErrors[40] = "NO_OUTSTANDING_VARIABLE_DEBT";
        aaveErrors[41] = "UNDERLYING_BALANCE_ZERO";
        aaveErrors[42] = "INTEREST_RATE_REBALANCE_CONDITIONS_NOT_MET";
        aaveErrors[43] = "HEALTH_FACTOR_NOT_BELOW_THRESHOLD";
        aaveErrors[44] = "COLLATERAL_CANNOT_BE_LIQUIDATED";
        aaveErrors[45] = "SPECIFIED_CURRENCY_NOT_BORROWED_BY_USER";
        aaveErrors[46] = "SAME_BLOCK_BORROW_REPAY";
        aaveErrors[47] = "INCONSISTENT_FLASHLOAN_PARAMS";
        aaveErrors[48] = "BORROW_CAP_EXCEEDED";
        aaveErrors[49] = "SUPPLY_CAP_EXCEEDED";
        aaveErrors[50] = "UNBACKED_MINT_CAP_EXCEEDED";
        aaveErrors[51] = "DEBT_CEILING_EXCEEDED";
        aaveErrors[52] = "ATOKEN_SUPPLY_NOT_ZERO";
        aaveErrors[53] = "STABLE_DEBT_NOT_ZERO";
        aaveErrors[54] = "VARIABLE_DEBT_SUPPLY_NOT_ZERO";
        aaveErrors[55] = "LTV_VALIDATION_FAILED";
        aaveErrors[56] = "INCONSISTENT_EMODE_CATEGORY";
        aaveErrors[57] = "PRICE_ORACLE_SENTINEL_CHECK_FAILED";
        aaveErrors[58] = "ASSET_NOT_BORROWABLE_IN_ISOLATION";
        aaveErrors[59] = "RESERVE_ALREADY_INITIALIZED";
        aaveErrors[60] = "USER_IN_ISOLATION_MODE_OR_LTV_ZERO";
        aaveErrors[61] = "INVALID_LTV";
        aaveErrors[62] = "INVALID_LIQ_THRESHOLD";
        aaveErrors[63] = "INVALID_LIQ_BONUS";
        aaveErrors[64] = "INVALID_DECIMALS";
        aaveErrors[65] = "INVALID_RESERVE_FACTOR";
        aaveErrors[66] = "INVALID_BORROW_CAP";
        aaveErrors[67] = "INVALID_SUPPLY_CAP";
        aaveErrors[68] = "INVALID_LIQUIDATION_PROTOCOL_FEE";
        aaveErrors[69] = "INVALID_EMODE_CATEGORY";
        aaveErrors[70] = "INVALID_UNBACKED_MINT_CAP";
        aaveErrors[71] = "INVALID_DEBT_CEILING";
        aaveErrors[72] = "INVALID_RESERVE_INDEX";
        aaveErrors[73] = "ACL_ADMIN_CANNOT_BE_ZERO";
        aaveErrors[74] = "INCONSISTENT_PARAMS_LENGTH";
        aaveErrors[75] = "ZERO_ADDRESS_NOT_VALID";
        aaveErrors[76] = "INVALID_EXPIRATION";
        aaveErrors[77] = "INVALID_SIGNATURE";
        aaveErrors[78] = "OPERATION_NOT_SUPPORTED";
        aaveErrors[79] = "DEBT_CEILING_NOT_ZERO";
        aaveErrors[80] = "ASSET_NOT_LISTED";
        aaveErrors[81] = "INVALID_OPTIMAL_USAGE_RATIO";
        aaveErrors[82] = "INVALID_OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO";
        aaveErrors[83] = "UNDERLYING_CANNOT_BE_RESCUED";
        aaveErrors[84] = "ADDRESSES_PROVIDER_ALREADY_ADDED";
        aaveErrors[85] = "POOL_ADDRESSES_DO_NOT_MATCH";
        aaveErrors[86] = "STABLE_BORROWING_ENABLED";
        aaveErrors[87] = "SILOED_BORROWING_VIOLATION";
        aaveErrors[88] = "RESERVE_DEBT_NOT_ZERO";
        aaveErrors[90] = "MATH_MULTIPLICATION_OVERFLOW";
        aaveErrors[91] = "MATH_ADDITION_OVERFLOW";
        aaveErrors[92] = "MATH_DIVISION_BY_ZERO";
    }

    function run() public {
        console.log("DirectAaveTest - Starting");
        console.log("Using AAVE Pool at:");
        console.log(AAVE_POOL);
        console.log("User address:");
        console.log(user);
        
        vm.startBroadcast(userPrivateKey);
        
        // Check balances
        uint256 usdtBalance = IERC20(USDT).balanceOf(user);
        uint256 usdcBalance = IERC20(USDC).balanceOf(user);
        
        console.log("USDT balance:");
        console.log(usdtBalance);
        console.log("USDC balance:");
        console.log(usdcBalance);
        
        // Define a very small amount to test with: 0.1 USDT
        uint256 supplyAmount = 100000; // 0.1 USDT
        
        if (usdtBalance < supplyAmount) {
            console.log("Not enough USDT. Need at least 0.1 USDT");
            // Attempt to mint tokens for testing if on testnet
            if (FAUCET_ADDRESS != address(0)) {
                try IFaucet(FAUCET_ADDRESS).mint(USDT, supplyAmount) {
                    usdtBalance = IERC20(USDT).balanceOf(user);
                    console.log("Minted USDT. New balance:");
                    console.log(usdtBalance / 1e6);
                } catch {
                    console.log("Failed to mint USDT. Please fund your account manually.");
                    vm.stopBroadcast();
                    return;
                }
            } else {
                console.log("No faucet available on mainnet. Please fund your account manually.");
                vm.stopBroadcast();
                return;
            }
        }
        
        if (usdtBalance >= supplyAmount) {
            // Step 1: Approve USDT
            console.log("Approving USDT for AAVE Pool...");
            IERC20(USDT).approve(AAVE_POOL, supplyAmount);
            
            // Step 2: Supply directly to AAVE
            console.log("Supplying 0.1 USDT directly to AAVE...");
            try IPool(AAVE_POOL).supply(USDT, supplyAmount, user, 0) {
                console.log("Supply successful");
                
                // Get the aToken address and check balance after supply
                try IPool(AAVE_POOL).getReserveData(USDT) returns (IPool.ReserveData memory reserveData) {
                    console.log("USDT aToken address:");
                    console.log(reserveData.aTokenAddress);
                    uint256 aTokenBalance = IERC20(reserveData.aTokenAddress).balanceOf(user);
                    console.log("aToken balance after supply:");
                    console.log(aTokenBalance);
                } catch {
                    console.log("Failed to get reserve data");
                }
                
                // Step 3: Try to enable as collateral
                console.log("Setting USDT as collateral...");
                try IPool(AAVE_POOL).setUserUseReserveAsCollateral(USDT, true) {
                    console.log("Successfully set as collateral");
                } catch {
                    console.log("Failed to set as collateral");
                    
                    // Check account data anyway
                    (
                        uint256 totalCollateralBase,
                        uint256 totalDebtBase,
                        uint256 availableBorrowsBase,
                        uint256 currentLiquidationThreshold,
                        uint256 ltv,
                        uint256 healthFactor
                    ) = IPool(AAVE_POOL).getUserAccountData(user);
                    
                    console.log("Account data:");
                    console.log("Total Collateral (USD):");
                    console.log(totalCollateralBase);
                    console.log("Total Debt (USD):");
                    console.log(totalDebtBase);
                    console.log("Available Borrows (USD):");
                    console.log(availableBorrowsBase);
                    console.log("Current Liquidation Threshold:");
                    console.log(currentLiquidationThreshold);
                    console.log("LTV:");
                    console.log(ltv);
                    console.log("Health Factor:");
                    console.log(healthFactor);
                }
                
                // Step 4: Try to borrow a tiny amount (0.01 USDC)
                uint256 borrowAmount = 10000; // 0.01 USDC
                console.log("Attempting to borrow 0.01 USDC directly from AAVE...");
                try IPool(AAVE_POOL).borrow(USDC, borrowAmount, 2, 0, user) {
                    console.log("Borrow successful");
                    
                    // Check new USDC balance
                    uint256 newUsdcBalance = IERC20(USDC).balanceOf(user);
                    console.log("New USDC balance:");
                    console.log(newUsdcBalance);
                    console.log("USDC increase:");
                    console.log(newUsdcBalance - usdcBalance);
                    
                    // Check updated account data
                    (
                        uint256 totalCollateralBase,
                        uint256 totalDebtBase,
                        uint256 availableBorrowsBase,
                        ,  // currentLiquidationThreshold
                        ,  // ltv
                        uint256 healthFactor
                    ) = IPool(AAVE_POOL).getUserAccountData(user);
                    
                    console.log("Updated account data:");
                    console.log("Total Collateral (USD):");
                    console.log(totalCollateralBase);
                    console.log("Total Debt (USD):");
                    console.log(totalDebtBase);
                    console.log("Available Borrows (USD):");
                    console.log(availableBorrowsBase);
                    console.log("Health Factor:");
                    console.log(healthFactor);
                } catch (bytes memory lowLevelData) {
                    console.log("Borrow failed");
                    
                    uint256 errorCode;
                    assembly {
                        errorCode := mload(add(lowLevelData, 0x44)) // Extract error code
                    }
                    string memory errorMsg = aaveErrors[errorCode];
                    if (bytes(errorMsg).length > 0) {
                        console.log("AAVE Error code:");
                        console.log(errorCode);
                        console.log("Error meaning:");
                        console.log(errorMsg);
                    } else {
                        console.log("Unknown error code:");
                        console.log(errorCode);
                    }
                }
                
                // Step 5: Repay the borrowed USDC before withdrawal
                console.log("Repaying borrowed USDC...");
                uint256 borrowedAmount = 10000; // 0.01 USDC
                // Approve USDC for repayment
                IERC20(USDC).approve(AAVE_POOL, borrowedAmount);
                
                try IPool(AAVE_POOL).repay(USDC, borrowedAmount, 2, user) returns (uint256 repaidAmount) {
                    console.log("Repayment successful, amount repaid:");
                    console.log(repaidAmount);
                    
                    // Check updated account data after repayment
                    (
                        uint256 totalCollateralBase,
                        uint256 totalDebtBase,
                        uint256 availableBorrowsBase,
                        ,  // currentLiquidationThreshold
                        ,  // ltv
                        uint256 healthFactor
                    ) = IPool(AAVE_POOL).getUserAccountData(user);
                    
                    console.log("Account data after repayment:");
                    console.log("Total Collateral (USD):");
                    console.log(totalCollateralBase);
                    console.log("Total Debt (USD):");
                    console.log(totalDebtBase);
                    console.log("Available Borrows (USD):");
                    console.log(availableBorrowsBase);
                    console.log("Health Factor:");
                    console.log(healthFactor);
                } catch (bytes memory lowLevelData) {
                    console.log("Repayment failed");
                    
                    uint256 errorCode;
                    assembly {
                        errorCode := mload(add(lowLevelData, 0x44)) // Extract error code
                    }
                    string memory errorMsg = aaveErrors[errorCode];
                    if (bytes(errorMsg).length > 0) {
                        console.log("AAVE Error code:");
                        console.log(errorCode);
                        console.log("Error meaning:");
                        console.log(errorMsg);
                    } else {
                        console.log("Unknown error code:");
                        console.log(errorCode);
                    }
                }
                
                // Step 6: Withdraw the supplied USDT at the end
                console.log("Withdrawing supplied USDT...");
                try IPool(AAVE_POOL).withdraw(USDT, supplyAmount, user) returns (uint256 withdrawn) {
                    console.log("Withdraw successful, amount withdrawn:");
                    console.log(withdrawn);
                } catch (bytes memory lowLevelData) {
                    console.log("Withdraw failed");
                    
                    uint256 errorCode;
                    assembly {
                        errorCode := mload(add(lowLevelData, 0x44)) // Extract error code
                    }
                    string memory errorMsg = aaveErrors[errorCode];
                    if (bytes(errorMsg).length > 0) {
                        console.log("AAVE Error code:");
                        console.log(errorCode);
                        console.log("Error meaning:");
                        console.log(errorMsg);
                    } else {
                        console.log("Unknown error code:");
                        console.log(errorCode);
                    }
                }
            } catch Error(string memory reason) {
                console.log("Failed to supply USDT:");
                console.log(reason);
                vm.stopBroadcast();
                return;
            } catch (bytes memory lowLevelData) {
                uint256 errorCode;
                assembly {
                    errorCode := mload(add(lowLevelData, 0x44)) // Extract error code
                }
                string memory errorMsg = aaveErrors[errorCode];
                if (bytes(errorMsg).length > 0) {
                    console.log("Failed to supply USDT. AAVE Error code:");
                    console.log(errorCode);
                    console.log("Error meaning:");
                    console.log(errorMsg);
                } else {
                    console.log("Failed to supply USDT. Unknown error code:");
                    console.log(errorCode);
                }
                vm.stopBroadcast();
                return;
            }
        }
        
        vm.stopBroadcast();
        console.log("DirectAaveTest - Finished");
    }
} 