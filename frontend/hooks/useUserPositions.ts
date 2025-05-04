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
  collateralAssetSymbol?: string;
  borrowAssetSymbol?: string;
  // Legacy field for backward compatibility
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
    '0xceba9300f2b948710d2653dd7b07f33a8b32118c': 'USDC',
    '0x48065fbbe25f71c9282ddf5e1cd6d6a887483d5e': 'USDT',
  };
  
  // Process positions data
  useEffect(() => {
    if (isConnected && positionIds && positionDetails && !isPositionIdsLoading && !isPositionDetailsLoading) {
      try {
        const ids = positionIds as unknown as bigint[];
        const details = positionDetails as Position[];
        
        // Combine IDs with details
        const processedPositions = details.map((position, index) => {
          // Get asset symbols from the addresses - make sure to lowercase for comparison
          const collateralAssetSymbol = tokenAddressToSymbol[position.collateralAsset.toLowerCase()] || 'Unknown';
          const borrowAssetSymbol = tokenAddressToSymbol[position.borrowAsset.toLowerCase()] || 'Unknown';
          
          // Format amounts to readable strings
          const formattedCollateralAmount = formatUnits(position.collateralAmount, 6); // Assuming 6 decimals for stablecoins
          const formattedBorrowAmount = formatUnits(position.borrowAmount, 6);
          
          return {
            ...position,
            positionId: Number(ids[index]),
            collateralAssetSymbol,
            borrowAssetSymbol,
            assetSymbol: collateralAssetSymbol, // Legacy support
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