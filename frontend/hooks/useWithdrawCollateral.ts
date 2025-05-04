import { useState, useEffect } from 'react';
import { useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { CONTRACT_ADDRESSES, LENDY_POSITION_MANAGER_ABI, prepareTokenAmount } from '@/lib/contracts';

export function useWithdrawCollateral() {
  const [isLoading, setIsLoading] = useState(false);
  const [isSuccess, setIsSuccess] = useState(false);
  const [error, setError] = useState<Error | null>(null);
  const [txHash, setTxHash] = useState<string | undefined>(undefined);

  const { writeContract, isPending, data: hash } = useWriteContract();
  
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

  // Withdraw collateral from a position
  const withdrawCollateral = async (positionId: number, amount: string, decimals: number = 6, withdrawAll: boolean = false, resetOnly: boolean = false) => {
    // If resetOnly is true, just reset the state and return
    if (resetOnly) {
      setIsLoading(false);
      setError(null);
      setIsSuccess(false);
      setTxHash(undefined);
      return;
    }
    
    try {
      setIsLoading(true);
      setError(null);
      setIsSuccess(false);
      setTxHash(undefined);
      
      console.log(`Withdrawing ${withdrawAll ? 'all' : amount} collateral from position ${positionId}`);
      
      // If withdrawing all, use the full amount - the contract will check against the actual available amount
      const tokenAmount = withdrawAll 
        ? BigInt("115792089237316195423570985008687907853269984665640564039457584007913129639935") // max uint256
        : prepareTokenAmount(amount, decimals);
      
      await writeContract({
        address: CONTRACT_ADDRESSES.lendyPositionManager,
        abi: LENDY_POSITION_MANAGER_ABI,
        functionName: 'withdrawCollateral',
        args: [BigInt(positionId), tokenAmount],
      });
      
    } catch (err) {
      console.error('Error withdrawing collateral:', err);
      setError(err instanceof Error ? err : new Error('Failed to withdraw collateral'));
      setIsLoading(false);
    }
  };

  return {
    withdrawCollateral,
    isLoading: isLoading || isPending || isConfirming,
    isSuccess,
    error,
    txHash
  };
} 