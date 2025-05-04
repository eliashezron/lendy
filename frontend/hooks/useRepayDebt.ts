import { useState, useEffect } from 'react';
import { useWriteContract, useWaitForTransactionReceipt, useReadContract } from 'wagmi';
import { CONTRACT_ADDRESSES, LENDY_POSITION_MANAGER_ABI, ERC20_ABI, prepareTokenAmount } from '@/lib/contracts';
import { tokenAddresses } from './useTokenBalance';

// Max uint256 value as string (2^256 - 1)
const MAX_UINT256 = "115792089237316195423570985008687907853269984665640564039457584007913129639935";

// Token address to symbol mapping - used to identify borrowed assets
// Make sure addresses are stored in lowercase
const tokenAddressToSymbol: Record<string, string> = {
  '0xceba9300f2b948710d2653dd7b07f33a8b32118c': 'usdc',
  '0x48065fbbe25f71c9282ddf5e1cd6d6a887483d5e': 'usdt',
};

export function useRepayDebt() {
  const [isSuccess, setIsSuccess] = useState(false);
  const [error, setError] = useState<Error | null>(null);
  const [txHash, setTxHash] = useState<string | undefined>(undefined);
  const [approvalTxHash, setApprovalTxHash] = useState<`0x${string}` | undefined>(undefined);
  const [borrowTokenSymbol, setBorrowTokenSymbol] = useState<string | null>(null);
  const [currentPositionId, setCurrentPositionId] = useState<number | null>(null);

  // Track approval and repayment states separately
  const [isApprovalStepComplete, setIsApprovalStepComplete] = useState(false);
  const [repaymentHash, setRepaymentHash] = useState<`0x${string}` | undefined>(undefined);

  const { writeContract, isPending: isWritePending, data: hash } = useWriteContract();
  
  // Use readContract for the position details
  const { data: positionDetails, refetch: refetchPosition } = useReadContract({
    address: CONTRACT_ADDRESSES.lendyPositionManager,
    abi: LENDY_POSITION_MANAGER_ABI,
    functionName: 'getPositionDetails',
    args: currentPositionId ? [BigInt(currentPositionId)] : undefined,
    query: {
      enabled: currentPositionId !== null,
    },
  });
  
  // Wait for approval
  const { isLoading: isApprovalConfirming, isSuccess: isApprovalConfirmed } = 
    useWaitForTransactionReceipt({
      hash: approvalTxHash,
      query: {
        enabled: !!approvalTxHash,
      },
    });
  
  // Wait for debt repayment
  const { isLoading: isRepaymentConfirming, isSuccess: isRepaymentConfirmed } = 
    useWaitForTransactionReceipt({
      hash: repaymentHash,
      query: {
        enabled: !!repaymentHash,
      },
    });

  // Update approval state
  useEffect(() => {
    if (isApprovalConfirmed && !isApprovalStepComplete) {
      setIsApprovalStepComplete(true);
    }
  }, [isApprovalConfirmed, isApprovalStepComplete]);

  // Update success state and hash only when repayment (not approval) is confirmed
  useEffect(() => {
    if (repaymentHash && isRepaymentConfirmed && !isSuccess) {
      setIsSuccess(true);
      setTxHash(repaymentHash);
    }
  }, [repaymentHash, isRepaymentConfirmed, isSuccess]);

  const isLoading = isWritePending || isApprovalConfirming || isRepaymentConfirming;

  // Fetch position details to get the actual borrowed token
  const fetchPositionDetails = async (positionId: number) => {
    try {
      // Update the current position ID to trigger the useReadContract hook
      setCurrentPositionId(positionId);
      
      // Refetch position details and wait for the result
      await refetchPosition();
      
      // Extract borrowAsset from the result
      if (positionDetails) {
        // Extract the borrowed asset address from the position
        // Note: The position object is a tuple with numeric indices for each property
        const position = positionDetails as any;
        
        // Get the borrowAsset from the position object
        // Position format: [owner, collateralAsset, collateralAmount, borrowAsset, borrowAmount, interestRateMode, active]
        if (!position.borrowAsset) {
          console.error("Position details structure:", position);
          throw new Error("Position details don't contain borrowAsset field");
        }
        
        // Convert to lowercase for comparison with our mapping
        const borrowAssetAddress = position.borrowAsset.toLowerCase();
        console.log("Position details:", positionDetails);
        console.log("Raw borrow asset address:", position.borrowAsset);
        console.log("Lowercase borrow asset address:", borrowAssetAddress);
        
        // Look up the token symbol from the address
        const symbol = tokenAddressToSymbol[borrowAssetAddress];
        
        if (!symbol) {
          console.error("Unknown token address:", borrowAssetAddress);
          console.error("Available tokens:", Object.keys(tokenAddressToSymbol));
          throw new Error(`Unknown borrow asset address: ${borrowAssetAddress}`);
        }
        
        console.log(`Found borrow token for position ${positionId}: ${symbol}`);
        // Store the token symbol in state
        setBorrowTokenSymbol(symbol);
        return symbol;
      }
      
      throw new Error("Failed to fetch position details - no data returned");
    } catch (err) {
      console.error("Error fetching position details:", err);
      throw err;
    }
  };

  // Approve token for spending by the contract
  const approveToken = async (tokenSymbol: string, amount: string, decimals: number) => {
    const tokenAddress = tokenAddresses[tokenSymbol.toLowerCase() as keyof typeof tokenAddresses];
    if (!tokenAddress) {
      throw new Error(`Token ${tokenSymbol} not supported`);
    }
    
    console.log(`Approving ${amount} of token ${tokenSymbol} (${tokenAddress}) for repayment`);
    
    // For full repayment or amounts close to user's balance, use max approval
    // We'll use MAX_UINT256 to ensure the approval is sufficient
    const tokenAmount = BigInt(MAX_UINT256);
    
    console.log(`Using max approval amount to avoid insufficient approval issues`);
    
    return new Promise<void>((resolve, reject) => {
      writeContract({
        address: tokenAddress as `0x${string}`,
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

  const repayDebt = async (
    positionId: number, 
    amount: string, 
    positionTokenSymbol: string, 
    decimals: number, 
    isFullRepayment: boolean = false,
    resetOnly: boolean = false
  ) => {
    // If resetOnly is true, just reset the state and return without making any contract calls
    if (resetOnly) {
      setIsSuccess(false);
      setError(null);
      setTxHash(undefined);
      setApprovalTxHash(undefined);
      setRepaymentHash(undefined);
      setIsApprovalStepComplete(false);
      return;
    }
    
    try {
      setIsSuccess(false);
      setError(null);
      setTxHash(undefined);
      setApprovalTxHash(undefined);
      setRepaymentHash(undefined);
      setIsApprovalStepComplete(false);
      
      // First, determine the correct token symbol for the borrowed asset
      let repayTokenSymbol: string;
      
      try {
        // Get the correct borrow token symbol
        repayTokenSymbol = await fetchPositionDetails(positionId);
        console.log(`Using borrow token ${repayTokenSymbol} for repayment`);
      } catch (err) {
        // If we can't fetch the borrow token, fall back to the position token
        console.warn(`Falling back to position token ${positionTokenSymbol} for repayment`);
        repayTokenSymbol = positionTokenSymbol.toLowerCase();
      }
      
      // Check that the amount is valid
      let amountValue = parseFloat(amount);
      
      // Get position details to check if debt is very small
      const position = positionDetails as any;
      const borrowAmount = position?.borrowAmount || BigInt(0);
      console.log(`Position borrow amount: ${borrowAmount.toString()}`);
      
      // Check if this is a tiny debt (less than ~0.01 in value)
      // For extremely small debts, it's better to use closePosition instead of repayDebt
      // because Aave might return NO_DEBT_OF_SELECTED_TYPE error for negligible amounts
      const isVerySmallDebt = borrowAmount < BigInt(10000); // Less than 0.01 tokens (with 6 decimals)
      
      if (isVerySmallDebt || isFullRepayment) {
        console.log(`Detected very small debt amount or full repayment requested. Using closePosition instead.`);
        
        // First approve token for spending - always use max approval
        await approveToken(repayTokenSymbol, amount, decimals);
        
        // Wait longer for approval confirmation on Celo network
        console.log('Waiting for approval confirmation...');
        await new Promise(resolve => setTimeout(resolve, 5000));
        
        // Use closePosition instead of repayDebt which will handle tiny amounts better
        console.log(`Closing position #${positionId} instead of repaying tiny debt`);
        
        writeContract({
          address: CONTRACT_ADDRESSES.lendyPositionManager,
          abi: LENDY_POSITION_MANAGER_ABI,
          functionName: 'closePosition',
          args: [BigInt(positionId)],
        }, {
          onSuccess(hash: `0x${string}`) {
            console.log('Position close transaction hash:', hash);
            setRepaymentHash(hash);
          },
          onError(err: Error) {
            console.error('Error closing position:', err);
            setError(err);
          }
        });
        
        return;
      }
      
      // For normal repayments of sufficient size, proceed with standard repayDebt flow
      if (isFullRepayment) {
        console.log(`Full repayment requested for amount: ${amount}`);
      } else if (isNaN(amountValue) || amountValue <= 0) {
        throw new Error(`Invalid repayment amount: ${amount}`);
      }
      
      // First approve token for spending - always use max approval
      await approveToken(repayTokenSymbol, amount, decimals);
      
      // Wait longer for approval confirmation on Celo network
      console.log('Waiting for approval confirmation...');
      await new Promise(resolve => setTimeout(resolve, 5000));
      
      // For full repayment, use the actual debt amount instead of MAX_UINT256
      // This helps avoid "Bad Request" errors from the RPC node
      const tokenAmount = prepareTokenAmount(amount, decimals);
      
      console.log(`Repaying debt: position #${positionId}, amount: ${tokenAmount.toString()}`);
      
      // Repay debt
      writeContract({
        address: CONTRACT_ADDRESSES.lendyPositionManager,
        abi: LENDY_POSITION_MANAGER_ABI,
        functionName: 'repayDebt',
        args: [BigInt(positionId), tokenAmount],
      }, {
        onSuccess(hash: `0x${string}`) {
          console.log('Repayment transaction hash:', hash);
          setRepaymentHash(hash);
        },
        onError(err: Error) {
          console.error('Error repaying debt:', err);
          setError(err);
        }
      });
    } catch (err) {
      console.error('Error repaying debt:', err);
      if (err instanceof Error) {
        // Check for specific errors
        if (err.message.includes('transfer amount exceeds balance')) {
          setError(new Error('Insufficient token balance. Please make sure you have enough tokens to repay the debt.'));
        } else if (err.message.includes('39') || err.message.includes('NO_DEBT_OF_SELECTED_TYPE')) {
          // Error 39 from Aave - handle it gracefully
          setError(new Error('No debt to repay. The position might have already been repaid or the debt is too small. Try closing the position instead.'));
        } else {
          setError(err);
        }
      } else {
        setError(new Error('Failed to repay debt'));
      }
    }
  };

  return {
    repayDebt,
    isLoading,
    isSuccess,
    isApprovalStepComplete,
    error,
    txHash
  };
} 