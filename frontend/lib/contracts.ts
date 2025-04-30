import { parseUnits } from 'viem';

// Contract addresses
export const CONTRACT_ADDRESSES = {
  lendyPositionManager: '0xd2B508298fCC37261953684744ec4CCc734d5083' as `0x${string}`,
};

// ERC20 ABI for token approval
export const ERC20_ABI = [
  {
    inputs: [
      { name: 'spender', type: 'address' },
      { name: 'amount', type: 'uint256' },
    ],
    name: 'approve',
    outputs: [{ name: '', type: 'bool' }],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [
      { name: 'owner', type: 'address' },
      { name: 'spender', type: 'address' },
    ],
    name: 'allowance',
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
] as const;

// Minimal ABI for LendyPositionManager to create positions
export const LENDY_POSITION_MANAGER_ABI = [
  {
    inputs: [
      { name: '_token', type: 'address' },
      { name: '_amount', type: 'uint256' },
    ],
    name: 'createPosition',
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'nonpayable',
    type: 'function',
  },
] as const;

/**
 * Helper function to prepare token amount with the correct decimals
 * @param amount - The amount as a string
 * @param decimals - The token decimals
 * @returns The amount as a bigint with the correct decimals
 */
export function prepareTokenAmount(amount: string, decimals: number): bigint {
  try {
    return parseUnits(amount, decimals);
  } catch (error) {
    console.error('Error parsing token amount:', error);
    return BigInt(0);
  }
} 