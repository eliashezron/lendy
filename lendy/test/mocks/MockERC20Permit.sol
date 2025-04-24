// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {MockERC20} from "./MockERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

/**
 * @title MockERC20Permit
 * @notice Mock ERC20 token with EIP-2612 permit functionality for testing
 */
contract MockERC20Permit is MockERC20, IERC20Permit {
    // Mock nonces for each address
    mapping(address => uint256) private _nonces;
    
    // Mock domain separator - in a real contract this would be calculated based on chain ID, etc.
    bytes32 private constant _MOCK_DOMAIN_SEPARATOR = keccak256("MockERC20Permit");

    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals_
    ) MockERC20(name, symbol, decimals_) {}

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     */
    function nonces(address owner) external view returns (uint256) {
        return _nonces[owner];
    }

    /**
     * @dev Returns the domain separator used in the encoding of the signature for {permit}.
     */
    function DOMAIN_SEPARATOR() external pure returns (bytes32) {
        return _MOCK_DOMAIN_SEPARATOR;
    }

    /**
     * @dev Mock implementation of permit that does minimal validation
     * In a real implementation, this would validate the signature, but for testing
     * we just increment the nonce and assume the signature is valid
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(deadline >= block.timestamp, "ERC20Permit: expired deadline");
        
        // Increment nonce
        _nonces[owner]++;
        
        // Approve spender
        _approve(owner, spender, value);
        
        emit Approval(owner, spender, value);
    }
} 