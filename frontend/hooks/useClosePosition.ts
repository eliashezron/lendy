import { useState, useEffect } from 'react';
import { useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { CONTRACT_ADDRESSES, LENDY_POSITION_MANAGER_ABI } from '@/lib/contracts';

export function useClosePosition() {
  const [isSuccess, setIsSuccess] = useState(false);
  const [error, setError] = useState<Error | null>(null);
  const [txHash, setTxHash] = useState<string | undefined>(undefined);

  const { writeContract, isPending: isWritePending, data: hash } = useWriteContract();
  
  const { isLoading: isConfirming } = useWaitForTransactionReceipt({
    hash,
    query: {
      enabled: !!hash,
    },
  });

  // Update success state and hash when transaction is confirmed
  useEffect(() => {
    if (hash && !isConfirming && !isSuccess) {
      setIsSuccess(true);
      setTxHash(hash);
    }
  }, [hash, isConfirming, isSuccess]);

  const isLoading = isWritePending || isConfirming;

  const closePosition = async (positionId: number) => {
    try {
      setIsSuccess(false);
      setError(null);
      setTxHash(undefined);
      
      await writeContract({
        address: CONTRACT_ADDRESSES.lendyPositionManager,
        abi: LENDY_POSITION_MANAGER_ABI,
        functionName: 'closePosition',
        args: [BigInt(positionId)],
      });
    } catch (err) {
      setError(err instanceof Error ? err : new Error('Failed to close position'));
      console.error('Error closing position:', err);
    }
  };

  return {
    closePosition,
    isLoading,
    isSuccess,
    error,
    txHash
  };
} 