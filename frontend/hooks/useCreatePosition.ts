import { useState, useEffect } from 'react';
import { useWriteContract, useWaitForTransactionReceipt, useAccount } from 'wagmi';
import { tokenAddresses } from './useTokenBalance';
import { CONTRACT_ADDRESSES, LENDY_POSITION_MANAGER_ABI, prepareTokenAmount, ERC20_ABI } from '@/lib/contracts';

// Parameters for creating a borrow position
export interface BorrowParams {
  borrowAsset: string;         // Token symbol to borrow
  borrowAmount: string;        // Amount to borrow as string
  borrowDecimals: number;      // Decimals of the borrow asset
}

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
  
  const createPosition = async (
    collateralTokenSymbol: string, 
    collateralAmount: string, 
    collateralDecimals: number,
    borrowParams: BorrowParams
  ) => {
    if (!isConnected) {
      throw new Error('Wallet not connected');
    }

    try {
      setIsLoading(true);
      setError(null);
      setIsSuccess(false);
      
      // Get collateral token address
      const collateralTokenAddress = tokenAddresses[collateralTokenSymbol.toLowerCase() as keyof typeof tokenAddresses];
      if (!collateralTokenAddress) {
        throw new Error(`Collateral token ${collateralTokenSymbol} not supported`);
      }
      
      // Convert collateral amount to token units with decimals
      const collateralAmountInWei = prepareTokenAmount(collateralAmount, collateralDecimals);
      
      // Check if collateral amount is too small
      const minAmount = BigInt(100000); // 0.1 with 6 decimals
      if (collateralAmountInWei < minAmount) {
        throw new Error(`Amount is too small. Minimum deposit is 0.1 ${collateralTokenSymbol.toUpperCase()}`);
      }
      
      // Get borrow token address
      const borrowTokenAddress = tokenAddresses[borrowParams.borrowAsset.toLowerCase() as keyof typeof tokenAddresses];
      if (!borrowTokenAddress) {
        throw new Error(`Borrow token ${borrowParams.borrowAsset} not supported`);
      }
      
      // Convert borrow amount to token units with decimals
      const borrowAmountInWei = prepareTokenAmount(borrowParams.borrowAmount, borrowParams.borrowDecimals);
      
      // Ensure borrow amount is not zero
      if (borrowAmountInWei === BigInt(0)) {
        throw new Error('Borrow amount must be greater than 0');
      }
      
      console.log('Starting borrow position creation with:');
      console.log('- Collateral:', collateralTokenSymbol, collateralAmount);
      console.log('- Borrowing:', borrowParams.borrowAsset, borrowParams.borrowAmount);
      
      // First request token approval for collateral
      try {
        console.log('Requesting collateral token approval');
        await approveToken(collateralTokenAddress as `0x${string}`, collateralAmountInWei);
        
        // Wait longer for approval to propagate on Celo network
        console.log('Waiting for approval confirmation...');
        await new Promise(resolve => setTimeout(resolve, 5000));
        
        console.log('Proceeding to create position');
        
        const variableInterestRate = BigInt(2); // Using variable rate (2)
        
        // Write to contract to create position
        writeContract({
          address: CONTRACT_ADDRESSES.lendyPositionManager,
          abi: LENDY_POSITION_MANAGER_ABI,
          functionName: 'createPosition',
          args: [
            collateralTokenAddress as `0x${string}`,  // collateralAsset
            collateralAmountInWei,                    // collateralAmount
            borrowTokenAddress as `0x${string}`,      // borrowAsset
            borrowAmountInWei,                        // borrowAmount
            variableInterestRate                      // interestRateMode (2 for variable)
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
            
            // Provide more user-friendly error message
            let errorMessage = err.message;
            if (errorMessage.includes('user rejected transaction')) {
              errorMessage = 'Transaction was rejected by user.';
            } else if (errorMessage.includes('Internal JSON-RPC error')) {
              errorMessage = 'The lending protocol rejected this transaction. Try using a larger deposit amount or check that you have enough CELO for gas fees.';
            }
            
            setError(new Error(errorMessage));
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
    txHash,
    // Expose these for transaction step UI
    isApprovalStepComplete: isApprovalConfirmed,
    approvalTxHash
  };
} 