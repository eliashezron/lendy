import { useState } from 'react';
import { useWriteContract, useWaitForTransactionReceipt, useAccount } from 'wagmi';
import { tokenAddresses } from './useTokenBalance';
import { CONTRACT_ADDRESSES, LENDY_POSITION_MANAGER_ABI, prepareTokenAmount } from '@/lib/contracts';

export function useCreatePosition() {
  const [isLoading, setIsLoading] = useState(false);
  const [isSuccess, setIsSuccess] = useState(false);
  const [error, setError] = useState<Error | null>(null);
  const [txHash, setTxHash] = useState<`0x${string}` | undefined>(undefined);
  const [positionId, setPositionId] = useState<bigint | null>(null);
  
  const { isConnected } = useAccount();
  
  const { writeContract, isPending } = useWriteContract();
  
  const { isLoading: isConfirming, isSuccess: isConfirmed } = 
    useWaitForTransactionReceipt({
      hash: txHash,
    });
  
  const createPosition = async (tokenSymbol: string, amount: string, decimals: number) => {
    if (!isConnected) {
      throw new Error('Wallet not connected');
    }

    try {
      setIsLoading(true);
      setError(null);
      setIsSuccess(false);
      
      // Get token address from tokenSymbol
      const tokenAddress = tokenAddresses[tokenSymbol as keyof typeof tokenAddresses];
      if (!tokenAddress) {
        throw new Error(`Token ${tokenSymbol} not supported`);
      }
      
      // Convert amount to token units with decimals
      const tokenAmount = prepareTokenAmount(amount, decimals);
      
      // Write to contract
      writeContract({
        address: CONTRACT_ADDRESSES.lendyPositionManager,
        abi: LENDY_POSITION_MANAGER_ABI,
        functionName: 'createPosition',
        args: [tokenAddress as `0x${string}`, tokenAmount],
      }, {
        onSuccess(hash: `0x${string}`) {
          setTxHash(hash);
        },
        onError(err: Error) {
          setError(err);
          setIsLoading(false);
        },
      });
    } catch (err) {
      console.error('Error creating position:', err);
      setError(err instanceof Error ? err : new Error(String(err)));
      setIsLoading(false);
    }
  };
  
  // Set loading state based on transaction status
  if (isConfirmed && isLoading) {
    setIsLoading(false);
    setIsSuccess(true);
  }
  
  return {
    createPosition,
    isLoading: isLoading || isPending || isConfirming,
    isSuccess: isSuccess || isConfirmed,
    error,
    txHash
  };
} 