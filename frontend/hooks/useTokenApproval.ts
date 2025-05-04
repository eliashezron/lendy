import { useState, useEffect } from 'react';
import { useWriteContract, useReadContract, useWaitForTransactionReceipt } from 'wagmi';
import { parseUnits } from 'viem';
import { ERC20_ABI, CONTRACT_ADDRESSES } from '@/lib/contracts';

export function useTokenApproval(tokenAddress: `0x${string}` | undefined) {
  const [isApproved, setIsApproved] = useState(false);
  const [isCheckingApproval, setIsCheckingApproval] = useState(false);
  const [isApproving, setIsApproving] = useState(false);
  const [error, setError] = useState<Error | null>(null);
  const [txHash, setTxHash] = useState<string | undefined>(undefined);
  const [amount, setAmount] = useState<string>('0');
  const [owner, setOwner] = useState<`0x${string}` | undefined>(undefined);

  const { writeContract, data: hash } = useWriteContract();
  
  // Wait for transaction receipt
  const { isLoading: isWaitingForReceipt, isSuccess: isReceiptSuccess } = useWaitForTransactionReceipt({
    hash,
    query: {
      enabled: !!hash,
    },
  });
  
  // Update state after transaction
  useEffect(() => {
    if (hash && isReceiptSuccess) {
      setIsApproved(true);
      setTxHash(hash);
      // Trigger refetch of allowance
      refetchAllowance();
    }
  }, [hash, isReceiptSuccess]);
  
  // Read current allowance
  const { data: allowance, refetch: refetchAllowance } = useReadContract({
    address: tokenAddress,
    abi: ERC20_ABI,
    functionName: 'allowance',
    args: [owner as `0x${string}`, CONTRACT_ADDRESSES.lendyPositionManager],
    query: {
      enabled: !!tokenAddress && !!owner,
    }
  });

  // Check if approval is needed
  useEffect(() => {
    const checkApproval = async () => {
      if (!tokenAddress || !amount || !allowance || !owner) return;
      
      try {
        setIsCheckingApproval(true);
        
        // Parse amount to wei (assuming 6 decimals for stablecoins)
        const amountInWei = parseUnits(amount, 6);
        
        // Compare allowance with required amount
        setIsApproved(allowance >= amountInWei);
      } catch (err) {
        console.error('Error checking approval:', err);
        setError(err instanceof Error ? err : new Error('Failed to check approval'));
      } finally {
        setIsCheckingApproval(false);
      }
    };
    
    checkApproval();
  }, [tokenAddress, amount, allowance, owner]);

  // Approve tokens
  const approveTokens = async () => {
    if (!tokenAddress || !amount || !owner) {
      setError(new Error('Missing required parameters for token approval'));
      return;
    }
    
    try {
      setIsApproving(true);
      setError(null);
      setTxHash(undefined);
      
      // Max uint256 value for unlimited approval
      const maxApproval = parseUnits('115792089237316195423570985008687907853269984665640564039457584007913129639935', 0);
      
      // Send approval transaction
      await writeContract({
        address: tokenAddress,
        abi: ERC20_ABI,
        functionName: 'approve',
        args: [CONTRACT_ADDRESSES.lendyPositionManager, maxApproval],
      });
      
    } catch (err) {
      console.error('Error approving tokens:', err);
      setError(err instanceof Error ? err : new Error('Failed to approve tokens'));
      setIsApproved(false);
      setIsApproving(false);
    }
  };
  
  // Update isApproving state based on transaction status
  useEffect(() => {
    if (!isWaitingForReceipt && isApproving) {
      setIsApproving(false);
    }
  }, [isWaitingForReceipt, isApproving]);

  // Set up approval check for a specific amount and owner
  const checkAndApprove = (newAmount: string, newOwner: `0x${string}`) => {
    setAmount(newAmount);
    setOwner(newOwner);
  };

  return {
    isApproved,
    isCheckingApproval,
    isApproving: isApproving || isWaitingForReceipt, 
    error,
    txHash,
    approveTokens,
    checkAndApprove
  };
} 