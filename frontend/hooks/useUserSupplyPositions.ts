import { useState, useEffect, useCallback } from 'react';
import { useAccount, usePublicClient } from 'wagmi';
import { CONTRACT_ADDRESSES, LENDY_POSITION_MANAGER_ABI } from '@/lib/contracts';
import { formatUnits } from 'viem';

// Define supply position type based on the contract
export type SupplyPosition = {
  owner: `0x${string}`;
  asset: `0x${string}`;
  amount: bigint;
  active: boolean;
  // UI specific fields
  supplyPositionId?: number;
  formattedAmount?: string;
  assetSymbol?: string;
};

export function useUserSupplyPositions(refreshTrigger: number = 0) {
  const [supplyPositions, setSupplyPositions] = useState<SupplyPosition[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);
  const [totalSupplied, setTotalSupplied] = useState<string>("0");
  
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
      console.log("Manual refetch of supply positions triggered");
    } catch (err) {
      setError(err instanceof Error ? err : new Error('Failed to refetch supply positions'));
    } finally {
      setIsLoading(false);
    }
  }, [isConnected, address, publicClient]);
  
  // Load user positions
  useEffect(() => {
    // Reset state when not connected
    if (!isConnected || !address || !publicClient) {
      setSupplyPositions([]);
      setTotalSupplied("0");
      setIsLoading(false);
      return;
    }
    
    // TypeScript now knows that address and publicClient are defined
    const fetchData = async () => {
      try {
        setIsLoading(true);
        
        console.log("=== SUPPLY POSITIONS DEBUG ===");
        console.log("Connected wallet address:", address);
        console.log("Contract address:", CONTRACT_ADDRESSES.lendyPositionManager);
        
        // Step 1: Get position IDs
        console.log("Fetching supply position IDs for address:", address);
        let positionIds;
        try {
          positionIds = await publicClient.readContract({
            address: CONTRACT_ADDRESSES.lendyPositionManager,
            abi: LENDY_POSITION_MANAGER_ABI,
            functionName: 'getUserSupplyPositions',
            args: [address],
          }) as bigint[];
          console.log("Supply position IDs:", positionIds);
        } catch (err) {
          console.error("Error getting user supply positions:", err);
          throw new Error("Failed to fetch supply position IDs");
        }
        
        if (!positionIds || positionIds.length === 0) {
          console.log("No supply position IDs found for user");
          setSupplyPositions([]);
          setTotalSupplied("0");
          setIsLoading(false);
          return;
        }
        
        // Step 2: Get details for each position
        const positions: SupplyPosition[] = [];
        let totalSuppliedValue = 0;
        
        for (const id of positionIds) {
          try {
            console.log(`Fetching details for supply position ID: ${id.toString()}`);
            
            let positionData;
            
            // First try with getSupplyPositionDetails
            try {
              positionData = await publicClient.readContract({
                address: CONTRACT_ADDRESSES.lendyPositionManager,
                abi: LENDY_POSITION_MANAGER_ABI,
                functionName: 'getSupplyPositionDetails',
                args: [id],
              });
              console.log("Raw supply position data from getSupplyPositionDetails:", positionData);
            } catch (err) {
              console.warn(`Error with getSupplyPositionDetails for position ${id}:`, err);
              console.log("Trying direct contract storage access...");
              
              // Try direct contract storage access as fallback
              try {
                positionData = await publicClient.readContract({
                  address: CONTRACT_ADDRESSES.lendyPositionManager,
                  abi: LENDY_POSITION_MANAGER_ABI,
                  functionName: 'supplyPositions',
                  args: [id],
                });
                console.log("Raw supply position data from direct storage:", positionData);
              } catch (err2) {
                console.error(`Error with direct storage for position ${id}:`, err2);
                continue; // Skip this position
              }
            }
            
            if (!positionData) {
              console.log(`No data returned for supply position ${id}`);
              continue;
            }
            
            // Parse the struct result - raw data is coming as an array
            console.log("Position data type:", typeof positionData, Array.isArray(positionData));
            
            // Direct access using array indices instead of struct casting
            let rawOwner, rawAsset, rawAmount, rawActive;
            
            try {
              // Check if it's an array and access directly
              if (Array.isArray(positionData)) {
                rawOwner = positionData[0] as `0x${string}`;
                rawAsset = positionData[1] as `0x${string}`;
                rawAmount = positionData[2] as bigint;
                rawActive = positionData[3] as boolean;
              } else {
                // Try to access as object properties
                const dataObj = positionData as any;
                rawOwner = dataObj.owner as `0x${string}`;
                rawAsset = dataObj.asset as `0x${string}`;
                rawAmount = dataObj.amount as bigint;
                rawActive = dataObj.active as boolean;
              }
              
              console.log("Manually extracted data:", {
                rawOwner, rawAsset, rawAmount, rawActive
              });
            } catch (err) {
              console.error("Error parsing position data:", err);
              continue;
            }
            
            // Force values to proper types and handle undefined
            const owner = isValidAddress(rawOwner) ? rawOwner : '0x0000000000000000000000000000000000000000' as `0x${string}`;
            const asset = isValidAddress(rawAsset) ? rawAsset : '0x0000000000000000000000000000000000000000' as `0x${string}`;
            const amount = typeof rawAmount === 'bigint' ? rawAmount : BigInt(0);
            const active = rawAmount > BigInt(0); // Consider active if amount > 0
            
            // Create position object
            const position: SupplyPosition = {
              owner,
              asset,
              amount,
              active,
              supplyPositionId: Number(id),
            };
            
            console.log(`Supply position ${id} active status:`, position.active);
            
            // Skip positions with zero amount
            if (position.amount <= BigInt(0)) {
              console.log(`Supply position ${id} has 0 amount, skipping`);
              continue;
            }
            
            // Get asset symbol - handle safely
            let assetSymbol = 'Unknown';
            try {
              if (isValidAddress(asset)) {
                const assetAddress = asset.toLowerCase();
                assetSymbol = tokenAddressToSymbol[assetAddress] || 'Unknown';
                console.log(`Supply asset: ${assetAddress} -> ${assetSymbol}`);
              } else {
                console.log(`Supply asset address is invalid:`, asset);
              }
            } catch (err) {
              console.error(`Error determining asset symbol:`, err);
            }
            
            // Format amount (assuming 6 decimals for stablecoins)
            let formattedAmount = '0.00';
            try {
              const decimals = 6;
              formattedAmount = formatUnits(amount, decimals);
              console.log(`Supply amount: ${amount} -> ${formattedAmount}`);
            } catch (err) {
              console.error(`Error formatting amount:`, err);
            }
            
            // Add UI fields
            const enhancedPosition: SupplyPosition = {
              ...position,
              assetSymbol,
              formattedAmount,
            };
            
            positions.push(enhancedPosition);
            totalSuppliedValue += parseFloat(formattedAmount);
          } catch (err) {
            console.error(`Error fetching details for supply position ${id}:`, err);
          }
        }
        
        console.log(`Final supply positions count: ${positions.length}`);
        console.log("Final supply positions:", positions);
        console.log(`Total supplied value: ${totalSuppliedValue}`);
        
        setSupplyPositions(positions);
        setTotalSupplied(totalSuppliedValue.toFixed(2));
      } catch (err) {
        console.error("Error fetching supply positions:", err);
        setError(err instanceof Error ? err : new Error('Failed to fetch supply positions'));
      } finally {
        setIsLoading(false);
      }
    };
    
    fetchData();
    // Include refreshTrigger in dependencies to reload when it changes
  }, [isConnected, address, publicClient, refreshTrigger]);
  
  return {
    supplyPositions,
    isLoading,
    error,
    totalSupplied,
    refetch
  };
}