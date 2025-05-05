import { useAccount, useReadContract, usePublicClient } from 'wagmi';
import { formatUnits, createPublicClient, http } from 'viem';
import { useEffect, useState, useCallback } from 'react';
import { celo } from 'viem/chains';

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
  const [isMiniPay, setIsMiniPay] = useState<boolean>(false);
  const { address, isConnected } = useAccount();
  const publicClient = usePublicClient();

  // Check if user is using MiniPay
  useEffect(() => {
    if (window.ethereum?.isMiniPay) {
      setIsMiniPay(true);
    }
  }, []);

  const tokenAddress = tokenSymbol ? tokenAddresses[tokenSymbol as keyof typeof tokenAddresses] : undefined;

  // Use Wagmi's hook for standard wallet connections
  const { data: balanceData } = useReadContract({
    address: tokenAddress as `0x${string}`,
    abi: erc20ABI,
    functionName: 'balanceOf',
    args: [address as `0x${string}`],
    query: {
      enabled: !!address && !!tokenAddress && isConnected && !isMiniPay,
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

  // Direct method for MiniPay users
  const fetchMiniPayBalance = useCallback(async () => {
    if (!isConnected || !address || !tokenAddress || !isMiniPay) return;

    try {
      console.log('Fetching balance for MiniPay user...');
      // Create a custom client for direct interaction
      const client = publicClient || createPublicClient({
        chain: celo,
        transport: http(),
      });

      // Fetch decimals first
      const fetchedDecimals = await client.readContract({
        address: tokenAddress as `0x${string}`,
        abi: erc20ABI,
        functionName: 'decimals',
      });

      // Set decimals
      if (fetchedDecimals) {
        setDecimals(Number(fetchedDecimals));
      }

      // Fetch balance
      const fetchedBalance = await client.readContract({
        address: tokenAddress as `0x${string}`,
        abi: erc20ABI,
        functionName: 'balanceOf',
        args: [address],
      });

      // Update balance state
      if (fetchedBalance) {
        const rawBal = fetchedBalance as bigint;
        setRawBalance(rawBal);
        setBalance(formatUnits(rawBal, Number(fetchedDecimals) || decimals));
        console.log('MiniPay balance fetched:', formatUnits(rawBal, Number(fetchedDecimals) || decimals));
      }
    } catch (error) {
      console.error('Error fetching MiniPay balance:', error);
    }
  }, [address, decimals, isConnected, isMiniPay, publicClient, tokenAddress]);

  // Effect for MiniPay users
  useEffect(() => {
    if (isMiniPay && isConnected && address && tokenAddress) {
      fetchMiniPayBalance();
    }
  }, [address, fetchMiniPayBalance, isConnected, isMiniPay, tokenAddress]);

  // Effect for standard wallet users
  useEffect(() => {
    if (decimalsData) {
      setDecimals(Number(decimalsData));
    }
  }, [decimalsData]);

  useEffect(() => {
    // Only update for standard wallet users (not MiniPay)
    if (balanceData && !isMiniPay) {
      const rawBal = balanceData as bigint;
      setRawBalance(rawBal);
      setBalance(formatUnits(rawBal, decimals));
    } else if (!isMiniPay) {
      // Reset for non-MiniPay users when no data
      setRawBalance(BigInt(0));
      setBalance('0.00');
    }
  }, [balanceData, decimals, isMiniPay]);

  return { balance, rawBalance, decimals, isMiniPay, refetch: fetchMiniPayBalance };
} 