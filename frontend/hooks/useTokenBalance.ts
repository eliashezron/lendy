import { useAccount, useReadContract } from 'wagmi';
import { formatUnits } from 'viem';
import { useEffect, useState } from 'react';

// ERC20 ABI (minimal for balanceOf function)
const erc20ABI = [
  {
    inputs: [{ name: 'owner', type: 'address' }],
    name: 'balanceOf',
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'decimals',
    outputs: [{ name: '', type: 'uint8' }],
    stateMutability: 'view',
    type: 'function',
  }
];

// Token addresses from the blockchain
export const tokenAddresses = {
  usdc: '0xcebA9300f2b948710d2653dD7B07f33A8B32118C',
  usdt: '0x48065fbBE25f71C9282ddf5e1cD6D6A887483D5e',
};

export function useTokenBalance(tokenSymbol: string | null) {
  const [balance, setBalance] = useState<string>('0.00');
  const [rawBalance, setRawBalance] = useState<bigint>(BigInt(0));
  const [decimals, setDecimals] = useState<number>(6); // Default for stablecoins
  const { address, isConnected } = useAccount();

  const tokenAddress = tokenSymbol ? tokenAddresses[tokenSymbol as keyof typeof tokenAddresses] : undefined;

  const { data: balanceData } = useReadContract({
    address: tokenAddress as `0x${string}`,
    abi: erc20ABI,
    functionName: 'balanceOf',
    args: [address as `0x${string}`],
    query: {
      enabled: !!address && !!tokenAddress && isConnected,
    },
  });

  const { data: decimalsData } = useReadContract({
    address: tokenAddress as `0x${string}`,
    abi: erc20ABI,
    functionName: 'decimals',
    query: {
      enabled: !!tokenAddress && isConnected,
    },
  });

  useEffect(() => {
    if (decimalsData) {
      setDecimals(Number(decimalsData));
    }
  }, [decimalsData]);

  useEffect(() => {
    if (balanceData) {
      const rawBal = balanceData as bigint;
      setRawBalance(rawBal);
      setBalance(formatUnits(rawBal, decimals));
    } else {
      setRawBalance(BigInt(0));
      setBalance('0.00');
    }
  }, [balanceData, decimals]);

  return { balance, rawBalance, decimals };
} 