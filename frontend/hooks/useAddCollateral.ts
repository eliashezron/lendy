import { useState, useEffect } from 'react';
import { useWriteContract, useWaitForTransactionReceipt, useAccount } from 'wagmi';
import { parseUnits } from 'viem';
import { CONTRACT_ADDRESSES, LENDY_POSITION_MANAGER_ABI, ERC20_ABI } from '@/lib/contracts';

// Token addresses by symbol
const TOKEN_ADDRESSES: Record<string, `0x${string}`> = {
  'USDC': CONTRACT_ADDRESSES.usdc,
  'USDT': CONTRACT_ADDRESSES.usdt,
};

export function useAddCollateral() {
  const [isSuccess, setIsSuccess] = useState(false);
  const [error, setError] = useState<Error | null>(null);
  const [txHash, setTxHash] = useState<string | undefined>(undefined);
  const [needsApproval, setNeedsApproval] = useState(false);
  const { address } = useAccount();

  // Contract write hooks
  const { writeContract: writePosition, isPending: isPositionPending, data: positionHash } = useWriteContract();
  const { writeContract: writeApproval, isPending: isApprovalPending, data: approvalHash } = useWriteContract();
  
  // Wait for transaction receipts
  const { isLoading: isPositionConfirming } = useWaitForTransactionReceipt({
    hash: positionHash,
    query: {
      enabled: !!positionHash,
    },
  });

  const { isLoading: isApprovalConfirming } = useWaitForTransactionReceipt({
    hash: approvalHash,
    query: {
      enabled: !!approvalHash,
    },
  });

  // Update state when position transaction is confirmed
  useEffect(() => {
    if (positionHash && !isPositionConfirming && !isSuccess) {
      setIsSuccess(true);
      setTxHash(positionHash);
    }
  }, [positionHash, isPositionConfirming, isSuccess]);

  // Update state when approval transaction is confirmed
  useEffect(() => {
    if (approvalHash && !isApprovalConfirming) {
      setNeedsApproval(false);
      setTxHash(approvalHash);
    }
  }, [approvalHash, isApprovalConfirming]);

  // Calculate loading state
  const isLoading = isPositionPending || isPositionConfirming || isApprovalPending || isApprovalConfirming;

  // Main function to add collateral with approval handling
  const addCollateral = async (positionId: number, amount: string, tokenSymbol: string) => {
    if (!address) {
      setError(new Error('Wallet not connected'));
      return;
    }

    try {
      // Reset states
      setIsSuccess(false);
      setError(null);
      setTxHash(undefined);
      
      // Get token address from symbol
      const tokenAddress = TOKEN_ADDRESSES[tokenSymbol];
      if (!tokenAddress) {
        throw new Error(`Unknown token symbol: ${tokenSymbol}`);
      }
      
      // Parse amount to wei (assuming 6 decimals for stablecoins)
      const amountInWei = parseUnits(amount, 6);
      
      // Check if approval is needed by sending max approval
      const maxApproval = parseUnits('115792089237316195423570985008687907853269984665640564039457584007913129639935', 0);
      
      try {
        setNeedsApproval(true);
        
        // Send approval transaction
        await writeApproval({
          address: tokenAddress,
          abi: ERC20_ABI,
          functionName: 'approve',
          args: [CONTRACT_ADDRESSES.lendyPositionManager, maxApproval],
        });
        
        // Wait for approval to be confirmed before proceeding
        // This will happen in the useEffect hook
      } catch (approvalErr) {
        console.error('Token approval failed:', approvalErr);
        setError(approvalErr instanceof Error ? approvalErr : new Error('Failed to approve token'));
        setNeedsApproval(false);
        return;
      }
      
      // Wait for approval confirmation (handled in useEffect)
      await new Promise<void>(resolve => {
        const checkApproval = () => {
          if (!needsApproval) {
            resolve();
          } else {
            setTimeout(checkApproval, 1000);
          }
        };
        checkApproval();
      });
      
      // Call contract to add collateral
      await writePosition({
        address: CONTRACT_ADDRESSES.lendyPositionManager,
        abi: LENDY_POSITION_MANAGER_ABI,
        functionName: 'addCollateral',
        args: [BigInt(positionId), amountInWei],
      });
    } catch (err) {
      setError(err instanceof Error ? err : new Error('Failed to add collateral'));
      console.error('Error adding collateral:', err);
    }
  };

  return {
    addCollateral,
    isLoading,
    isSuccess,
    error,
    txHash
  };
} 