import { useState, useEffect } from 'react';
import { useWriteContract, useReadContract, useWaitForTransactionReceipt, useAccount } from 'wagmi';
import { tokenAddresses } from './useTokenBalance';
import { CONTRACT_ADDRESSES, LENDY_POSITION_MANAGER_ABI, prepareTokenAmount, ERC20_ABI } from '@/lib/contracts';

// Position creation modes
export enum PositionMode {
  EARN_ONLY = 'earn_only',   // Only supply, no borrowing
  BORROW = 'borrow'          // Supply and borrow
}

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
    tokenSymbol: string, 
    amount: string, 
    decimals: number,
    mode: PositionMode = PositionMode.EARN_ONLY,
    borrowParams?: BorrowParams
  ) => {
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
      
      // Check if amount is too small (minimum 0.1 token for stable coins)
      const minAmount = BigInt(100000); // 0.1 with 6 decimals
      if (tokenAmount < minAmount) {
        throw new Error(`Amount is too small. Minimum deposit is 0.1 ${tokenSymbol.toUpperCase()}`);
      }
      
      console.log('Starting position creation flow with token:', tokenAddress, 'amount:', tokenAmount.toString());
      
      // First request token approval
      try {
        console.log('Requesting token approval first');
        await approveToken(tokenAddress as `0x${string}`, tokenAmount);
        
        // Wait longer for approval to propagate on Celo network
        console.log('Waiting for approval confirmation...');
        await new Promise(resolve => setTimeout(resolve, 5000));
        
        console.log('Proceeding to create position');
        
        // The createPosition function in the contract requires 5 parameters:
        // 1. collateralAsset (address)
        // 2. collateralAmount (uint256)
        // 3. borrowAsset (address)
        // 4. borrowAmount (uint256)
        // 5. interestRateMode (uint256) - 1 for stable, 2 for variable
        
        let borrowAssetAddress: `0x${string}`;
        let borrowAmountInWei: bigint;
        
        if (mode === PositionMode.BORROW && borrowParams) {
          // User is borrowing - use provided parameters
          const borrowTokenAddress = tokenAddresses[borrowParams.borrowAsset.toLowerCase() as keyof typeof tokenAddresses];
          if (!borrowTokenAddress) {
            throw new Error(`Borrow token ${borrowParams.borrowAsset} not supported`);
          }
          
          borrowAssetAddress = borrowTokenAddress as `0x${string}`;
          borrowAmountInWei = prepareTokenAmount(borrowParams.borrowAmount, borrowParams.borrowDecimals);
          
          // Ensure borrow amount is not zero
          if (borrowAmountInWei === BigInt(0)) {
            throw new Error('Borrow amount must be greater than 0');
          }
        } else {
          // For earn-only mode, we need to use the smallest possible valid borrow amount
          // The contract requires borrow amount > 0, so we use 1 wei of a different asset
          borrowAssetAddress = tokenSymbol.toLowerCase() === 'usdc' 
            ? CONTRACT_ADDRESSES.usdt  // If collateral is USDC, borrow USDT
            : CONTRACT_ADDRESSES.usdc; // If collateral is USDT, borrow USDC
            
          borrowAmountInWei = BigInt(1); // Minimum possible amount (1 wei)
        }
        
        const variableInterestRate = BigInt(2); // Using variable rate (2)
        
        console.log('Creating position with parameters:');
        console.log('- Collateral asset:', tokenAddress);
        console.log('- Collateral amount:', tokenAmount.toString());
        console.log('- Borrow asset:', borrowAssetAddress);
        console.log('- Borrow amount:', borrowAmountInWei.toString());
        console.log('- Interest rate mode:', variableInterestRate.toString());
        
        // Write to contract to create position with all 5 required arguments
        writeContract({
          address: CONTRACT_ADDRESSES.lendyPositionManager,
          abi: LENDY_POSITION_MANAGER_ABI,
          functionName: 'createPosition',
          args: [
            tokenAddress as `0x${string}`,  // collateralAsset
            tokenAmount,                    // collateralAmount
            borrowAssetAddress,             // borrowAsset
            borrowAmountInWei,              // borrowAmount
            variableInterestRate            // interestRateMode (2 for variable)
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
    txHash
  };
} 