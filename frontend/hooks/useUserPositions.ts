import { useState, useEffect, useCallback } from 'react';
import { useAccount, usePublicClient } from 'wagmi';
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

export function useUserPositions(refreshTrigger: number = 0) {
  const [positions, setPositions] = useState<Position[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);
  const [totalCollateral, setTotalCollateral] = useState<string>("0");
  const [totalBorrowed, setTotalBorrowed] = useState<string>("0");
  
  const { address, isConnected } = useAccount();
  const publicClient = usePublicClient();
  
  // Token address to symbol mapping
  const tokenAddressToSymbol: Record<string, string> = {
    [CONTRACT_ADDRESSES.usdc.toLowerCase()]: 'USDC',
    [CONTRACT_ADDRESSES.usdt.toLowerCase()]: 'USDT',
  };
  
  // Add a utility function to safely check if a value is an address
  const isValidAddress = (value: any): boolean => {
    return typeof value === 'string' && 
           value.startsWith('0x') && 
           value.length === 42;
  };
  
  // Create a refetch function to manually trigger data refresh
  const refetch = useCallback(async () => {
    if (!isConnected || !address || !publicClient) {
      return;
    }
    
    try {
      setIsLoading(true);
      // Actual fetch logic is in the useEffect, this just triggers it
      console.log("Manual refetch of positions triggered");
    } catch (err) {
      setError(err instanceof Error ? err : new Error('Failed to refetch positions'));
    } finally {
      setIsLoading(false);
    }
  }, [isConnected, address, publicClient]);
  
  // Load user positions
  useEffect(() => {
    // Reset state when not connected
    if (!isConnected || !address || !publicClient) {
      setPositions([]);
      setTotalCollateral("0");
      setTotalBorrowed("0");
      setIsLoading(false);
      return;
    }
    
    // TypeScript now knows that address and publicClient are defined
    const fetchData = async () => {
      try {
        setIsLoading(true);
        
        console.log("=== BORROWING POSITIONS DEBUG ===");
        console.log("Connected wallet address:", address);
        console.log("Contract address:", CONTRACT_ADDRESSES.lendyPositionManager);
        
        // Step 1: Get position IDs
        console.log("Fetching position IDs for address:", address);
        let positionIds;
        try {
          positionIds = await publicClient.readContract({
            address: CONTRACT_ADDRESSES.lendyPositionManager,
            abi: LENDY_POSITION_MANAGER_ABI,
            functionName: 'getUserPositions',
            args: [address],
          }) as bigint[];
          console.log("Position IDs:", positionIds);
        } catch (err) {
          console.error("Error getting user positions:", err);
          throw new Error("Failed to fetch position IDs");
        }
        
        if (!positionIds || positionIds.length === 0) {
          console.log("No position IDs found for user");
          setPositions([]);
          setTotalCollateral("0");
          setTotalBorrowed("0");
          setIsLoading(false);
          return;
        }
        
        // Step 2: Get details for each position
        const fetchedPositions: Position[] = [];
        let totalCollateralValue = 0;
        let totalBorrowValue = 0;
        
        for (const id of positionIds) {
          try {
            console.log(`Fetching details for position ID: ${id.toString()}`);
            
            let positionData;
            
            // First try with getPositionDetails
            try {
              positionData = await publicClient.readContract({
                address: CONTRACT_ADDRESSES.lendyPositionManager,
                abi: LENDY_POSITION_MANAGER_ABI,
                functionName: 'getPositionDetails',
                args: [id],
              });
              console.log("Raw position data from getPositionDetails:", positionData);
            } catch (err) {
              console.warn(`Error with getPositionDetails for position ${id}:`, err);
              console.log("Trying direct contract storage access...");
              
              // Try direct contract storage access as fallback
              try {
                positionData = await publicClient.readContract({
                  address: CONTRACT_ADDRESSES.lendyPositionManager,
                  abi: LENDY_POSITION_MANAGER_ABI,
                  functionName: 'positions',
                  args: [id],
                });
                console.log("Raw position data from direct storage:", positionData);
              } catch (err2) {
                console.error(`Error with direct storage for position ${id}:`, err2);
                continue; // Skip this position
              }
            }
            
            if (!positionData) {
              console.log(`No data returned for position ${id}`);
              continue;
            }
            
            // Parse the data - raw data could be array or object
            console.log("Position data type:", typeof positionData, Array.isArray(positionData));
            
            // Direct access using array indices instead of struct casting
            let rawOwner, rawCollateralAsset, rawCollateralAmount, 
                rawBorrowAsset, rawBorrowAmount, rawInterestRateMode, rawActive;
            
            try {
              // Check if it's an array and access directly
              if (Array.isArray(positionData)) {
                rawOwner = positionData[0] as `0x${string}`;
                rawCollateralAsset = positionData[1] as `0x${string}`;
                rawCollateralAmount = positionData[2] as bigint;
                rawBorrowAsset = positionData[3] as `0x${string}`;
                rawBorrowAmount = positionData[4] as bigint;
                rawInterestRateMode = positionData[5] as bigint;
                rawActive = positionData[6] as boolean;
              } else {
                // Try to access as object properties
                const dataObj = positionData as any;
                rawOwner = dataObj.owner as `0x${string}`;
                rawCollateralAsset = dataObj.collateralAsset as `0x${string}`;
                rawCollateralAmount = dataObj.collateralAmount as bigint;
                rawBorrowAsset = dataObj.borrowAsset as `0x${string}`;
                rawBorrowAmount = dataObj.borrowAmount as bigint;
                rawInterestRateMode = dataObj.interestRateMode as bigint;
                rawActive = dataObj.active as boolean;
              }
              
              console.log("Manually extracted data:", {
                rawOwner, rawCollateralAsset, rawCollateralAmount, 
                rawBorrowAsset, rawBorrowAmount, rawInterestRateMode, rawActive
              });
            } catch (err) {
              console.error("Error parsing position data:", err);
              continue;
            }
            
            // Force values to proper types and handle undefined
            const owner = isValidAddress(rawOwner) ? 
              rawOwner : 
              '0x0000000000000000000000000000000000000000' as `0x${string}`;
              
            const collateralAsset = isValidAddress(rawCollateralAsset) ? 
              rawCollateralAsset : 
              '0x0000000000000000000000000000000000000000' as `0x${string}`;
              
            const collateralAmount = typeof rawCollateralAmount === 'bigint' ? 
              rawCollateralAmount : 
              BigInt(0);
              
            const borrowAsset = isValidAddress(rawBorrowAsset) ? 
              rawBorrowAsset : 
              '0x0000000000000000000000000000000000000000' as `0x${string}`;
              
            const borrowAmount = typeof rawBorrowAmount === 'bigint' ? 
              rawBorrowAmount : 
              BigInt(0);
              
            const interestRateMode = typeof rawInterestRateMode === 'bigint' ? 
              rawInterestRateMode : 
              BigInt(2); // Default to variable rate
              
            // Determine active status from data or derive from amounts
            const active = typeof rawActive === 'boolean' ? 
              rawActive : 
              (collateralAmount > BigInt(0)); // Position is active if it has collateral
            
            const position: Position = {
              owner,
              collateralAsset,
              collateralAmount,
              borrowAsset,
              borrowAmount,
              interestRateMode,
              active,
              positionId: Number(id),
            };
            
            console.log(`Position ${id} active status:`, position.active);
            
            // Skip positions with zero collateral
            if (position.collateralAmount <= BigInt(0)) {
              console.log(`Position ${id} has 0 collateral, skipping`);
              continue;
            }
            
            // Get asset symbols - handle safely
            let collateralAssetSymbol = 'Unknown';
            let borrowAssetSymbol = 'Unknown';
            
            try {
              if (isValidAddress(collateralAsset)) {
                const collateralAssetAddress = collateralAsset.toLowerCase();
                collateralAssetSymbol = tokenAddressToSymbol[collateralAssetAddress] || 'Unknown';
                console.log(`Collateral asset: ${collateralAssetAddress} -> ${collateralAssetSymbol}`);
              } else {
                console.log(`Collateral asset address is invalid:`, collateralAsset);
              }
              
              if (isValidAddress(borrowAsset)) {
                const borrowAssetAddress = borrowAsset.toLowerCase();
                borrowAssetSymbol = tokenAddressToSymbol[borrowAssetAddress] || 'Unknown';
                console.log(`Borrow asset: ${borrowAssetAddress} -> ${borrowAssetSymbol}`);
              } else {
                console.log(`Borrow asset address is invalid:`, borrowAsset);
              }
            } catch (err) {
              console.error(`Error determining asset symbols:`, err);
            }
            
            // Format amounts (assuming 6 decimals for stablecoins) - handle safely
            let formattedCollateralAmount = '0.00';
            let formattedBorrowAmount = '0.00';
            
            try {
              const decimals = 6;
              
              if (typeof collateralAmount === 'bigint') {
                formattedCollateralAmount = formatUnits(collateralAmount, decimals);
                console.log(`Collateral amount: ${collateralAmount} -> ${formattedCollateralAmount}`);
              }
              
              if (typeof borrowAmount === 'bigint') {
                formattedBorrowAmount = formatUnits(borrowAmount, decimals);
                console.log(`Borrow amount: ${borrowAmount} -> ${formattedBorrowAmount}`);
              }
            } catch (err) {
              console.error(`Error formatting amounts:`, err);
            }
            
            // Add UI fields
            const enhancedPosition: Position = {
              ...position,
              collateralAssetSymbol,
              borrowAssetSymbol,
              assetSymbol: collateralAssetSymbol, // Legacy support
              formattedCollateralAmount,
              formattedBorrowAmount,
            };
            
            fetchedPositions.push(enhancedPosition);
            
            // Calculate totals
            totalCollateralValue += parseFloat(formattedCollateralAmount);
            totalBorrowValue += parseFloat(formattedBorrowAmount);
          } catch (err) {
            console.error(`Error fetching details for position ${id}:`, err);
          }
        }
        
        console.log(`Final positions count: ${fetchedPositions.length}`);
        console.log("Final positions:", fetchedPositions);
        console.log(`Total collateral value: ${totalCollateralValue}`);
        console.log(`Total borrow value: ${totalBorrowValue}`);
        
        setPositions(fetchedPositions);
        setTotalCollateral(totalCollateralValue.toFixed(2));
        setTotalBorrowed(totalBorrowValue.toFixed(2));
      } catch (err) {
        console.error("Error fetching positions:", err);
        setError(err instanceof Error ? err : new Error('Failed to fetch positions'));
      } finally {
        setIsLoading(false);
      }
    };
    
    fetchData();
    
    // Include refreshTrigger in dependencies to reload when it changes
  }, [isConnected, address, publicClient, refreshTrigger]);
  
  return {
    positions,
    isLoading,
    error,
    totalCollateral,
    totalBorrowed,
    refetch
  };
} 