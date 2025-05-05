import { useState } from 'react';
import { useWriteContract, useWaitForTransactionReceipt, useAccount } from 'wagmi';
import { tokenAddresses } from './useTokenBalance';
import { CONTRACT_ADDRESSES, LENDY_POSITION_MANAGER_ABI, prepareTokenAmount, ERC20_ABI } from '@/lib/contracts';

export function useSupplyPosition() {
  const [isLoading, setIsLoading] = useState(false);
  const [isSuccess, setIsSuccess] = useState(false);
  const [error, setError] = useState<Error | null>(null);
  const [txHash, setTxHash] = useState<`0x${string}` | undefined>(undefined);
  const [supplyPositionId, setSupplyPositionId] = useState<bigint | null>(null);
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
  
  // Create a supply position
  const createSupplyPosition = async (
    tokenSymbol: string, 
    amount: string, 
    decimals: number
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
      
      // Debug logs for token amount
      console.log('Amount provided:', amount);
      console.log('Decimals:', decimals);
      console.log('Calculated token amount (BigInt):', tokenAmount.toString());
      
      // Check if amount is too small (minimum 0.1 token for stable coins)
      // For 6 decimals, 0.1 is 100000
      const minAmount = BigInt(100000); // 0.1 with 6 decimals
      if (tokenAmount < minAmount) {
        throw new Error(`Amount is too small. Minimum deposit is 0.1 ${tokenSymbol.toUpperCase()}`);
      }
      
      console.log('Starting supply position creation with token:', tokenAddress, 'amount:', tokenAmount.toString());
      
      // First request token approval
      try {
        console.log('Requesting token approval first');
        await approveToken(tokenAddress as `0x${string}`, tokenAmount);
        
        // Wait longer for approval confirmation
        console.log('Waiting for approval confirmation...');
        await new Promise(resolve => setTimeout(resolve, 5000));
        
        console.log('Proceeding to create supply position');
        console.log('Calling contract address:', CONTRACT_ADDRESSES.lendyPositionManager);
        console.log('With arguments:', [
          tokenAddress,
          tokenAmount.toString()
        ]);
        
        // Call the supply function
        writeContract({
          address: CONTRACT_ADDRESSES.lendyPositionManager,
          abi: LENDY_POSITION_MANAGER_ABI,
          functionName: 'supply',
          args: [
            tokenAddress as `0x${string}`,  // asset
            tokenAmount                     // amount
          ],
        }, {
          onSuccess(hash: `0x${string}`) {
            console.log('Supply position creation transaction hash:', hash);
            setTxHash(hash);
            setIsSuccess(true);
            setIsLoading(false);
          },
          onError(err: Error) {
            console.error('Error creating supply position:', err);
            
            // Provide more user-friendly error message
            let errorMessage = err.message;
            if (errorMessage.includes('user rejected transaction')) {
              errorMessage = 'Transaction was rejected by user.';
            } else if (errorMessage.includes('Internal JSON-RPC error')) {
              // Extract the inner error message if possible
              const match = errorMessage.match(/"message":"([^"]+)"/);
              if (match && match[1]) {
                errorMessage = `Contract error: ${match[1]}`;
              } else {
                errorMessage = 'The lending protocol rejected this transaction. Try using a larger deposit amount or check that you have enough CELO for gas fees.';
              }
            } else if (errorMessage.includes('Non-200 status code')) {
              errorMessage = 'The transaction was not processed correctly. Please make sure you have enough CELO for gas and that the amount you are supplying is valid.';
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
      console.error('Error creating supply position:', err);
      setError(err instanceof Error ? err : new Error(String(err)));
      setIsLoading(false);
    }
  };
  
  // Increase supply in an existing position
  const increaseSupply = async (
    supplyPositionId: number,
    tokenSymbol: string,
    additionalAmount: string,
    decimals: number
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
      const tokenAmount = prepareTokenAmount(additionalAmount, decimals);
      
      // Check if amount is too small
      if (tokenAmount <= BigInt(0)) {
        throw new Error(`Amount must be greater than 0`);
      }
      
      console.log('Adding to supply position:', supplyPositionId, 'token:', tokenAddress, 'amount:', tokenAmount.toString());
      
      // First request token approval
      try {
        console.log('Requesting token approval first');
        await approveToken(tokenAddress as `0x${string}`, tokenAmount);
        
        // Wait longer for approval to propagate on Celo network
        console.log('Waiting for approval confirmation...');
        await new Promise(resolve => setTimeout(resolve, 5000));
        
        console.log('Proceeding to increase supply');
        
        // Call the increaseSupply function
        writeContract({
          address: CONTRACT_ADDRESSES.lendyPositionManager,
          abi: LENDY_POSITION_MANAGER_ABI,
          functionName: 'increaseSupply',
          args: [
            BigInt(supplyPositionId),  // supplyPositionId
            tokenAmount                // additionalAmount
          ],
        }, {
          onSuccess(hash: `0x${string}`) {
            console.log('Increase supply transaction hash:', hash);
            setTxHash(hash);
            setIsSuccess(true);
            setIsLoading(false);
          },
          onError(err: Error) {
            console.error('Error increasing supply:', err);
            setError(err instanceof Error ? err : new Error(String(err)));
            setIsLoading(false);
          },
        });
      } catch (err) {
        console.error('Error in token approval process:', err);
        throw err;
      }
      
    } catch (err) {
      console.error('Error increasing supply:', err);
      setError(err instanceof Error ? err : new Error(String(err)));
      setIsLoading(false);
    }
  };
  
  // Withdraw supply from a position
  const withdrawSupply = async (
    supplyPositionId: number,
    withdrawAmount: string,
    decimals: number,
    isFullWithdrawal: boolean = false
  ) => {
    if (!isConnected) {
      throw new Error('Wallet not connected');
    }

    try {
      setIsLoading(true);
      setError(null);
      setIsSuccess(false);
      
      // For full withdrawals, use closeSupplyPosition
      if (isFullWithdrawal) {
        console.log('Closing supply position:', supplyPositionId);
        
        writeContract({
          address: CONTRACT_ADDRESSES.lendyPositionManager,
          abi: LENDY_POSITION_MANAGER_ABI,
          functionName: 'closeSupplyPosition',
          args: [BigInt(supplyPositionId)],
        }, {
          onSuccess(hash: `0x${string}`) {
            console.log('Close supply position transaction hash:', hash);
            setTxHash(hash);
            setIsSuccess(true);
            setIsLoading(false);
          },
          onError(err: Error) {
            console.error('Error closing supply position:', err);
            setError(err instanceof Error ? err : new Error(String(err)));
            setIsLoading(false);
          },
        });
      } else {
        // Partial withdrawal
        // Convert amount to token units with decimals
        const tokenAmount = prepareTokenAmount(withdrawAmount, decimals);
        
        // Check if amount is too small
        if (tokenAmount <= BigInt(0)) {
          throw new Error(`Amount must be greater than 0`);
        }
        
        console.log('Withdrawing from supply position:', supplyPositionId, 'amount:', tokenAmount.toString());
        
        // Call the withdrawSupply function
        writeContract({
          address: CONTRACT_ADDRESSES.lendyPositionManager,
          abi: LENDY_POSITION_MANAGER_ABI,
          functionName: 'withdrawSupply',
          args: [
            BigInt(supplyPositionId),  // supplyPositionId
            tokenAmount                // withdrawAmount
          ],
        }, {
          onSuccess(hash: `0x${string}`) {
            console.log('Withdraw supply transaction hash:', hash);
            setTxHash(hash);
            setIsSuccess(true);
            setIsLoading(false);
          },
          onError(err: Error) {
            console.error('Error withdrawing supply:', err);
            setError(err instanceof Error ? err : new Error(String(err)));
            setIsLoading(false);
          },
        });
      }
    } catch (err) {
      console.error('Error withdrawing supply:', err);
      setError(err instanceof Error ? err : new Error(String(err)));
      setIsLoading(false);
    }
  };
  
  return {
    createSupplyPosition,
    increaseSupply,
    withdrawSupply,
    isLoading: isLoading || isPending || isConfirming || isApprovalConfirming,
    isSuccess: isSuccess || isConfirmed,
    error,
    txHash,
    // Expose these for transaction step UI
    isApprovalStepComplete: isApprovalConfirmed,
    approvalTxHash
  };
} 