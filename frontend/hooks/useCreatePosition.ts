import { useState, useEffect } from 'react';
import { useWriteContract, useReadContract, useWaitForTransactionReceipt, useAccount } from 'wagmi';
import { tokenAddresses } from './useTokenBalance';
import { CONTRACT_ADDRESSES, LENDY_POSITION_MANAGER_ABI, prepareTokenAmount, ERC20_ABI } from '@/lib/contracts';

export function useCreatePosition() {
  const [isLoading, setIsLoading] = useState(false);
  const [isSuccess, setIsSuccess] = useState(false);
  const [error, setError] = useState<Error | null>(null);
  const [txHash, setTxHash] = useState<`0x${string}` | undefined>(undefined);
  const [positionId, setPositionId] = useState<bigint | null>(null);
  const [approvalTxHash, setApprovalTxHash] = useState<`0x${string}` | undefined>(undefined);
  
  const { address, isConnected } = useAccount();
  
  const { writeContract, isPending } = useWriteContract();
  
  const { isLoading: isConfirming, isSuccess: isConfirmed } = 
    useWaitForTransactionReceipt({
      hash: txHash,
    });
    
  const { isLoading: isApprovalConfirming, isSuccess: isApprovalConfirmed } = 
    useWaitForTransactionReceipt({
      hash: approvalTxHash,
    });

  // Approve token for spending by the contract
  const approveToken = async (tokenAddress: `0x${string}`, tokenAmount: bigint) => {
    if (!isConnected || !address) {
      throw new Error('Wallet not connected');
    }

    console.log('Requesting approval for token:', tokenAddress, 'amount:', tokenAmount.toString());
    
    return new Promise<void>((resolve, reject) => {
      writeContract({
        address: tokenAddress,
        abi: ERC20_ABI,
        functionName: 'approve',
        args: [CONTRACT_ADDRESSES.lendyPositionManager, tokenAmount],
      }, {
        onSuccess(hash: `0x${string}`) {
          console.log('Approval transaction hash:', hash);
          setApprovalTxHash(hash);
          resolve();
        },
        onError(err: Error) {
          console.error('Error approving token:', err);
          reject(err);
        },
      });
    });
  };
  
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
      
      console.log('Starting position creation flow with token:', tokenAddress, 'amount:', tokenAmount.toString());
      
      // First request token approval
      try {
        console.log('Requesting token approval first');
        await approveToken(tokenAddress as `0x${string}`, tokenAmount);
        
        // Wait briefly for approval to propagate
        await new Promise(resolve => setTimeout(resolve, 2000));
        
        console.log('Proceeding to create position');
        
        // The createPosition function in the contract requires 5 parameters:
        // 1. collateralAsset (address)
        // 2. collateralAmount (uint256)
        // 3. borrowAsset (address)
        // 4. borrowAmount (uint256)
        // 5. interestRateMode (uint256) - 1 for stable, 2 for variable
        
        // For this simplified version, we're only depositing (no borrowing)
        // so we'll set borrowAmount to 0 and use a default borrowAsset (can be the same token)
        const zeroAmount = BigInt(0);
        const variableInterestRate = BigInt(2); // Using variable rate (2)
        
        // Write to contract to create position with all 5 required arguments
        writeContract({
          address: CONTRACT_ADDRESSES.lendyPositionManager,
          abi: LENDY_POSITION_MANAGER_ABI,
          functionName: 'createPosition',
          args: [
            tokenAddress as `0x${string}`, // collateralAsset
            tokenAmount,                   // collateralAmount
            tokenAddress as `0x${string}`, // borrowAsset (same as collateral in this case)
            zeroAmount,                    // borrowAmount (0 for deposit only)
            variableInterestRate           // interestRateMode (2 for variable)
          ],
        }, {
          onSuccess(hash: `0x${string}`) {
            console.log('Position creation transaction hash:', hash);
            setTxHash(hash);
            setIsSuccess(true);
            setIsLoading(false);
          },
          onError(err: Error) {
            console.error('Error creating position:', err);
            setError(err);
            setIsLoading(false);
          },
        });
      } catch (err) {
        console.error('Error in token approval process:', err);
        throw err;
      }
      
    } catch (err) {
      console.error('Error creating position:', err);
      setError(err instanceof Error ? err : new Error(String(err)));
      setIsLoading(false);
    }
  };
  
  // Set loading state based on transaction status
  useEffect(() => {
    if (isConfirmed && isLoading) {
      setIsLoading(false);
      setIsSuccess(true);
    }
  }, [isConfirmed, isLoading]);
  
  return {
    createPosition,
    isLoading: isLoading || isPending || isConfirming || isApprovalConfirming,
    isSuccess: isSuccess || isConfirmed,
    error,
    txHash
  };
} 