import { useState, useEffect } from 'react';
import { useReadContract, useAccount } from 'wagmi';
import { CONTRACT_ADDRESSES, LENDY_POSITION_MANAGER_ABI } from '@/lib/contracts';
import { formatUnits } from 'viem';

// Define position type based on the contract
export type Position = {
  owner: `0x${string}`;
  collateralAsset: `0x${string}`;
  collateralAmount: bigint;
  borrowAsset: `0x${string}`;
  borrowAmount: bigint;
  interestRateMode: bigint;
  active: boolean;
  // UI specific fields
  positionId?: number;
  formattedCollateralAmount?: string;
  formattedBorrowAmount?: string;
  assetSymbol?: string;
};

export function useUserPositions() {
  const [positions, setPositions] = useState<Position[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);
  const [totalSupplied, setTotalSupplied] = useState<string>("0");
  const [totalCollateral, setTotalCollateral] = useState<string>("0");
  const [totalBorrowed, setTotalBorrowed] = useState<string>("0");
  
  const { address, isConnected } = useAccount();
  
  // Get user positions IDs
  const { data: positionIds, isError: isPositionIdsError, isLoading: isPositionIdsLoading } = useReadContract({
    address: CONTRACT_ADDRESSES.lendyPositionManager,
    abi: LENDY_POSITION_MANAGER_ABI,
    functionName: 'getUserPositions',
    args: [address as `0x${string}`],
    query: {
      enabled: isConnected && !!address,
    },
  });
  
  // Get detailed positions using getUserPositionsWithDetails
  const { data: positionDetails, isError: isPositionDetailsError, isLoading: isPositionDetailsLoading } = useReadContract({
    address: CONTRACT_ADDRESSES.lendyPositionManager,
    abi: LENDY_POSITION_MANAGER_ABI,
    functionName: 'getUserPositionsWithDetails',
    args: [address as `0x${string}`],
    query: {
      enabled: isConnected && !!address,
    },
  });
  
  // Token address to symbol mapping
  const tokenAddressToSymbol: Record<string, string> = {
    '0xcebA9300f2b948710d2653dD7B07f33A8B32118C': 'USDC',
    '0x48065fbBE25f71C9282ddf5e1cD6D6A887483D5e': 'USDT',
  };
  
  // Process positions data
  useEffect(() => {
    if (isConnected && positionIds && positionDetails && !isPositionIdsLoading && !isPositionDetailsLoading) {
      try {
        const ids = positionIds as unknown as bigint[];
        const details = positionDetails as Position[];
        
        // Combine IDs with details
        const processedPositions = details.map((position, index) => {
          // Get asset symbol from the address
          const assetSymbol = tokenAddressToSymbol[position.collateralAsset.toLowerCase() as string] || 'Unknown';
          
          // Format amounts to readable strings
          const formattedCollateralAmount = formatUnits(position.collateralAmount, 6); // Assuming 6 decimals for stablecoins
          const formattedBorrowAmount = formatUnits(position.borrowAmount, 6);
          
          return {
            ...position,
            positionId: Number(ids[index]),
            assetSymbol,
            formattedCollateralAmount,
            formattedBorrowAmount,
          };
        });
        
        // Filter only active positions
        const activePositions = processedPositions.filter(pos => pos.active);
        
        setPositions(activePositions);
        
        // Calculate totals for active positions
        let totalCollateralValue = 0;
        let totalBorrowValue = 0;
        
        activePositions.forEach(position => {
          const collateralValue = parseFloat(position.formattedCollateralAmount || '0');
          const borrowValue = parseFloat(position.formattedBorrowAmount || '0');
          
          totalCollateralValue += collateralValue;
          totalBorrowValue += borrowValue;
        });
        
        // Set totals (supplied == collateral for this simple case)
        setTotalSupplied(totalCollateralValue.toFixed(2));
        setTotalCollateral(totalCollateralValue.toFixed(2));
        setTotalBorrowed(totalBorrowValue.toFixed(2));
        
        setIsLoading(false);
      } catch (err) {
        console.error("Error processing positions:", err);
        setError(err instanceof Error ? err : new Error('Failed to process positions'));
        setIsLoading(false);
      }
    } else if (isPositionIdsError || isPositionDetailsError) {
      setError(new Error('Failed to fetch positions'));
      setIsLoading(false);
    }
  }, [
    isConnected, 
    positionIds, 
    positionDetails, 
    isPositionIdsLoading, 
    isPositionDetailsLoading, 
    isPositionIdsError, 
    isPositionDetailsError
  ]);
  
  return {
    positions,
    isLoading,
    error,
    totalSupplied,
    totalCollateral,
    totalBorrowed,
  };
} 