import { useState } from 'react';
import { useWaitForTransactionReceipt, useWriteContract } from 'wagmi';
import { CONTRACT_ADDRESSES, LENDY_POSITION_MANAGER_ABI } from '@/lib/contracts';

/**
 * Hook for emergency closing positions that are giving errors
 * Note: This will only work if:
 * 1. The user is the contract owner, OR
 * 2. You adapt this to call a backend API endpoint that makes the admin call
 */
export function useEmergencyClose() {
  const [isLoading, setIsLoading] = useState(false);
  const [isSuccess, setIsSuccess] = useState(false);
  const [error, setError] = useState<Error | null>(null);
  const [txHash, setTxHash] = useState<string | undefined>(undefined);

  // For admin close functions
  const { writeContract, isPending, data: hash } = useWriteContract();
  
  const { isLoading: isConfirming } = useWaitForTransactionReceipt({
    hash,
    query: {
      enabled: !!hash,
    },
  });

  // Update states when transaction completes
  if (hash && !isConfirming && !isSuccess) {
    setIsSuccess(true);
    setTxHash(hash);
    setIsLoading(false);
  }

  /**
   * Emergency close a position that has problematic tiny debt
   * This would normally require you to be the owner of the contract
   * In production, this would typically call a backend API endpoint that makes this call
   */
  const emergencyClosePosition = async (positionId: number) => {
    try {
      setIsLoading(true);
      setError(null);
      setIsSuccess(false);
      setTxHash(undefined);
      
      console.log(`Attempting emergency close for position ${positionId}`);
      
      // Call adminClosePosition with emergencyClose=true
      await writeContract({
        address: CONTRACT_ADDRESSES.lendyPositionManager,
        abi: LENDY_POSITION_MANAGER_ABI,
        functionName: 'adminClosePosition',
        args: [BigInt(positionId), true], // true for emergency close
      });
      
    } catch (err) {
      console.error('Error in emergency close:', err);
      setError(err instanceof Error ? err : new Error('Failed to emergency close position'));
      setIsLoading(false);
    }
  };
  
  return {
    emergencyClosePosition,
    isLoading: isLoading || isPending || isConfirming,
    isSuccess,
    error,
    txHash,
  };
} 