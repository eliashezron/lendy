"use client";

import React, { useState, useEffect, useCallback } from "react";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/components/ui/tabs";
import { Info, Loader2, ExternalLink, Plus, CheckCircle, AlertCircle, ArrowRight } from "lucide-react";
import { useUserPositions, Position } from '@/hooks/useUserPositions';
import { useUserSupplyPositions, SupplyPosition } from '@/hooks/useUserSupplyPositions';
import { useAccount, usePublicClient } from "wagmi";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Alert, AlertTitle, AlertDescription } from "@/components/ui/alert";
import { useAddCollateral } from "@/hooks/useAddCollateral";
import { useClosePosition } from "@/hooks/useClosePosition";
import { useRepayDebt } from "@/hooks/useRepayDebt";
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group";
import { useTokenBalance } from "@/hooks/useTokenBalance";
import { useWithdrawCollateral } from "@/hooks/useWithdrawCollateral";
import { useRouter } from "next/navigation";
import { useEmergencyClose } from "@/hooks/useEmergencyClose";
import { useSupplyPosition } from "@/hooks/useSupplyPosition";
import { CONTRACT_ADDRESSES, LENDY_POSITION_MANAGER_ABI } from "@/lib/contracts";

// Debug flag - set to true to show extra debugging information in the UI
const __DEV__ = process.env.NODE_ENV === 'development';

// Supply APY rates from Aave
const SUPPLY_APY_RATES = {
  usdc: 1.2, // 1.2%
  usdt: 1.0, // 1.0%
};

export default function Positions() {
  const { isConnected, address } = useAccount();
  const publicClient = usePublicClient();
  const router = useRouter();
  
  // Add a refresh trigger state
  const [refreshTrigger, setRefreshTrigger] = useState<number>(0);
  
  // Get borrow positions with refresh trigger
  const { positions, isLoading: isPositionsLoading, error: positionsError, totalCollateral, totalBorrowed, refetch: refetchPositions } = useUserPositions(refreshTrigger);
  
  // Get supply positions with refresh trigger
  const { supplyPositions, isLoading: isSupplyPositionsLoading, error: supplyPositionsError, totalSupplied, refetch: refetchSupplyPositions } = useUserSupplyPositions(refreshTrigger);
  
  const [currentTab, setCurrentTab] = useState<string>("earning");
  
  // Dialog states
  const [modifyDialogOpen, setModifyDialogOpen] = useState(false);
  const [closeDialogOpen, setCloseDialogOpen] = useState(false);
  const [repayDialogOpen, setRepayDialogOpen] = useState(false);
  const [withdrawDialogOpen, setWithdrawDialogOpen] = useState(false);
  const [selectedPosition, setSelectedPosition] = useState<any>(null);
  const [additionalAmount, setAdditionalAmount] = useState("");
  const [repayAmount, setRepayAmount] = useState("");
  const [withdrawAmount, setWithdrawAmount] = useState("");
  const [repayType, setRepayType] = useState<"partial" | "full">("partial");
  const [withdrawType, setWithdrawType] = useState<"partial" | "full">("full");
  
  // Add states to track both asset types
  const [borrowTokenSymbol, setBorrowTokenSymbol] = useState<string | null>(null);
  const [borrowTokenBalance, setBorrowTokenBalance] = useState<string>("0");
  const [borrowTokenDecimals, setBorrowTokenDecimals] = useState<number>(6);
  
  // Update the token balance hook to get the borrow token balance
  const { balance: repayTokenBalance, decimals: repayTokenDecimals } = useTokenBalance(
    borrowTokenSymbol
  );
  
  // Update when repay token balance changes
  useEffect(() => {
    if (repayTokenBalance) {
      setBorrowTokenBalance(repayTokenBalance);
    }
    if (repayTokenDecimals) {
      setBorrowTokenDecimals(repayTokenDecimals);
    }
  }, [repayTokenBalance, repayTokenDecimals]);
  
  // Add this new state to track if a position has already failed repayment/closing
  const [hadFailedRepayment, setHadFailedRepayment] = useState(false);
  
  // Custom hooks for contract interaction
  const { addCollateral, isLoading: isAddingCollateral, isSuccess: isAddSuccess, error: addError, txHash: addTxHash } = useAddCollateral();
  const { closePosition, isLoading: isClosing, isSuccess: isCloseSuccess, error: closeError, txHash: closeTxHash } = useClosePosition();
  const { repayDebt, isLoading: isRepaying, isSuccess: isRepaySuccess, isApprovalStepComplete, error: repayError, txHash: repayTxHash } = useRepayDebt();
  const { withdrawCollateral, isLoading: isWithdrawing, isSuccess: isWithdrawSuccess, error: withdrawError, txHash: withdrawTxHash } = useWithdrawCollateral();
  const { emergencyClosePosition, isLoading: isEmergencyClosing, isSuccess: isEmergencySuccess, error: emergencyError, txHash: emergencyTxHash } = useEmergencyClose();
  
  // Add supply position hooks
  const { 
    increaseSupply, 
    withdrawSupply, 
    isLoading: isSupplyModifying, 
    isSuccess: isSupplyModified, 
    error: supplyModifyError, 
    txHash: supplyModifyTxHash 
  } = useSupplyPosition();

  // Filter positions based on the current tab - changed to show all positions
  const filteredPositions = positions.filter(position => {
    // Show all positions regardless of borrow amount
    if (currentTab === "borrowing") {
      // Include all positions that have any collateral
      return position.collateralAmount > BigInt(0);
    }
    return false;
  });

  const handleTabChange = (value: string) => {
    setCurrentTab(value);
    console.log(`Switched to tab: ${value}`);
    console.log(`Positions available: ${positions.length}`);
    console.log(`Supply positions available: ${supplyPositions.length}`);
  };

  const renderCurrency = (amount: string) => {
    return `$${amount}`;
  };
  
  // Handle opening the modify dialog
  const handleModifyClick = (position: any) => {
    setSelectedPosition(position);
    setAdditionalAmount("");
    setModifyDialogOpen(true);
  };
  
  // Handle opening the close dialog
  const handleCloseClick = (position: any) => {
    setSelectedPosition(position);
    setCloseDialogOpen(true);
  };
  
  // Handle opening the repay dialog with proper token mapping
  const handleRepayClick = (position: any) => {
    // Always reset the state before opening a new dialog
    repayDebt(0, "0", "", 0, false, true); // Call with reset flag
    
    setSelectedPosition(position);
    setRepayAmount("");
    setRepayType("partial");
    setRepayDialogOpen(true);
    
    console.log("Repaying position:", position);
    console.log("Borrow asset address:", position.borrowAsset);
    console.log("Borrow asset symbol:", position.borrowAssetSymbol);
    console.log("Collateral asset:", position.collateralAsset);
    console.log("Collateral asset symbol:", position.collateralAssetSymbol);
    
    // Always use the pre-calculated borrowAssetSymbol from the position if available
    if (position.borrowAssetSymbol && position.borrowAssetSymbol !== 'Unknown') {
      console.log("Using position's borrowAssetSymbol:", position.borrowAssetSymbol);
      setBorrowTokenSymbol(position.borrowAssetSymbol.toLowerCase());
      return;
    }
    
    // Fallback to token address mapping if needed
    // Token address to symbol mapping - make sure addresses are lowercase
    const tokenAddressToSymbol: Record<string, string> = {
      '0xceba9300f2b948710d2653dd7b07f33a8b32118c': 'usdc',
      '0x48065fbbe25f71c9282ddf5e1cd6d6a887483d5e': 'usdt',
    };
    
    // Determine the borrowed token symbol from the borrow asset address
    const borrowAssetAddress = position.borrowAsset.toLowerCase();
    const borrowSymbol = tokenAddressToSymbol[borrowAssetAddress] || null;
    
    console.log("Determined borrow token symbol from address mapping:", borrowSymbol);
    
    // Set the borrow token symbol for the repay dialog
    setBorrowTokenSymbol(borrowSymbol);
  };
  
  // Handle opening the withdraw dialog
  const handleWithdrawClick = (position: any) => {
    setSelectedPosition(position);
    setWithdrawAmount("");
    setWithdrawType("full");
    setWithdrawDialogOpen(true);
  };
  
  // Handler for adding collateral (for borrowing positions)
  const handleAddCollateral = async () => {
    if (!selectedPosition || !additionalAmount) return;
    
    try {
      await addCollateral(
        selectedPosition.positionId,
        additionalAmount,
        selectedPosition.collateralAssetSymbol || selectedPosition.assetSymbol
      );
    } catch (err) {
      console.error("Error adding collateral:", err);
    }
  };
  
  // Handle closing position
  const handleClosePosition = async () => {
    if (!selectedPosition?.positionId) return;
    
    try {
      console.log(`Closing position ${selectedPosition.positionId}`);
      await closePosition(selectedPosition.positionId);
      
      // Trigger refresh after successful close
      setTimeout(() => {
        setRefreshTrigger(prev => prev + 1);
      }, 2000); // Wait for blockchain to process
    } catch (err) {
      console.error("Error closing position:", err);
    }
  };
  
  // Handle repaying debt - update to track failures
  const handleRepayDebt = async () => {
    if (!selectedPosition) return;
    
    try {
      const isFullRepayment = repayType === "full";
      
      // For full repayment, add a small buffer (1%) to account for any interest accrual
      // during transaction processing
      let amount;
      if (isFullRepayment) {
        const debtAmount = parseFloat(selectedPosition.formattedBorrowAmount);
        const bufferedAmount = (debtAmount * 1.01).toFixed(6); // Add 1% buffer and format to 6 decimal places
        amount = bufferedAmount;
        console.log(`Using buffered amount for full repayment: ${amount} (original: ${selectedPosition.formattedBorrowAmount})`);
      } else {
        amount = repayAmount;
      }
      
      if (!isFullRepayment && (!amount || parseFloat(amount) <= 0)) {
        return;
      }
      
      // Ensure we have a valid borrow token symbol
      if (!borrowTokenSymbol) {
        throw new Error("Unable to determine borrow token type");
      }
      
      console.log(`Repaying debt for position ${selectedPosition.positionId}`);
      console.log(`Borrow token: ${borrowTokenSymbol}, Amount: ${amount}`);
      console.log(`Is full repayment: ${isFullRepayment}`);
      
      await repayDebt(
        selectedPosition.positionId,
        amount,
        borrowTokenSymbol,
        borrowTokenDecimals,
        isFullRepayment
      );
    } catch (err) {
      console.error("Failed to repay debt:", err);
      // Mark that we had a failure
      setHadFailedRepayment(true);
    }
  };
  
  // Add a new handler for emergency close
  const handleEmergencyClose = async () => {
    if (!selectedPosition) return;
    
    try {
      console.log(`Emergency closing position ${selectedPosition.positionId}`);
      await emergencyClosePosition(selectedPosition.positionId);
    } catch (err) {
      console.error("Failed emergency close:", err);
    }
  };
  
  // Handle withdrawing collateral
  const handleWithdrawCollateral = async () => {
    if (!selectedPosition) return;
    
    try {
      const isFullWithdrawal = withdrawType === "full";
      
      if (!isFullWithdrawal && (!withdrawAmount || parseFloat(withdrawAmount) <= 0)) {
        return;
      }
      
      // For positions with no debt, we can withdraw all collateral
      const amount = isFullWithdrawal ? selectedPosition.formattedCollateralAmount : withdrawAmount;
      const decimals = 6; // Assuming 6 decimals for stablecoins
      
      console.log(`Withdrawing collateral from position ${selectedPosition.positionId}`);
      console.log(`Amount: ${amount}, Is full withdrawal: ${isFullWithdrawal}`);
      
      await withdrawCollateral(
        selectedPosition.positionId,
        amount,
        decimals,
        isFullWithdrawal
      );
    } catch (err) {
      console.error("Failed to withdraw collateral:", err);
    }
  };
  
  // Handle adding supply
  const handleIncreaseSupply = async () => {
    if (!selectedPosition?.supplyPositionId || !additionalAmount) return;
    
    try {
      const decimals = selectedPosition.assetSymbol === 'USDC' || selectedPosition.assetSymbol === 'USDT' ? 6 : 18;
      
      console.log(`Increasing supply for position ${selectedPosition.supplyPositionId} with ${additionalAmount} ${selectedPosition.assetSymbol}`);
      
      await increaseSupply(
        selectedPosition.supplyPositionId,
        selectedPosition.assetSymbol.toLowerCase(),
        additionalAmount,
        decimals
      );
    } catch (err) {
      console.error("Error increasing supply:", err);
    }
  };
  
  // Handle closing supply position
  const handleCloseSupplyPosition = async () => {
    if (!selectedPosition?.supplyPositionId) return;
    
    try {
      console.log(`Closing supply position ${selectedPosition.supplyPositionId}`);
      
      // Call withdrawSupply with full withdrawal flag
      const decimals = selectedPosition.assetSymbol === 'USDC' || selectedPosition.assetSymbol === 'USDT' ? 6 : 18;
      await withdrawSupply(
        selectedPosition.supplyPositionId,
        "0", // Amount doesn't matter for full withdrawal
        decimals,
        true // isFullWithdrawal = true
      );
      
      // Trigger refresh after successful close
      setTimeout(() => {
        setRefreshTrigger(prev => prev + 1);
      }, 2000); // Wait for blockchain to process
    } catch (err) {
      console.error("Error closing supply position:", err);
    }
  };
  
  // Effect to reset dialogs after successful transactions and redirect on repayment
  useEffect(() => {
    if (isAddSuccess || isCloseSuccess || isWithdrawSuccess || isSupplyModified) {
      setModifyDialogOpen(false);
      setCloseDialogOpen(false);
      setWithdrawDialogOpen(false);
      setSelectedPosition(null);
      setAdditionalAmount("");
      setWithdrawAmount("");
      
      // Trigger refresh after successful transaction
      setTimeout(() => {
        setRefreshTrigger(prev => prev + 1);
      }, 2000); // Wait for blockchain to process
    }
    
    // For successful repayments, redirect to the Earning tab
    if (isRepaySuccess || isEmergencySuccess) {
      setRepayDialogOpen(false);
      setSelectedPosition(null);
      setRepayAmount("");
      setHadFailedRepayment(false); // Reset on success
      setCurrentTab("earning");
      
      // Trigger refresh after successful repayment
      setTimeout(() => {
        setRefreshTrigger(prev => prev + 1);
      }, 2000); // Wait for blockchain to process
      
      // Give a small delay before redirecting to ensure state is properly updated
      setTimeout(() => {
        router.push("/positions");
      }, 500);
    }
  }, [isAddSuccess, isCloseSuccess, isRepaySuccess, isWithdrawSuccess, isEmergencySuccess, isSupplyModified, router]);

  // Render transaction status with step tracking for repayment
  const renderRepaymentStatus = (isLoading: boolean, isSuccess: boolean, isApprovalStepComplete: boolean, error: Error | null, txHash: string | undefined) => {
    if (error) {
      return (
        <Alert variant="destructive" className="mb-4">
          <AlertCircle className="h-4 w-4 mr-2" />
          <AlertTitle>Transaction failed</AlertTitle>
          <AlertDescription>
            {error.message || "Could not complete transaction. Please try again."}
          </AlertDescription>
        </Alert>
      );
    }
    
    if (isLoading) {
      return (
        <div className="mb-4 space-y-2">
          {/* Approval step */}
          <Alert variant={isApprovalStepComplete ? "success" : "default"} className={isApprovalStepComplete ? "" : "animate-pulse"}>
            {isApprovalStepComplete ? (
              <CheckCircle className="h-4 w-4 mr-2" />
            ) : (
              <Loader2 className="h-4 w-4 mr-2 animate-spin" />
            )}
            <AlertTitle>Step 1: {isApprovalStepComplete ? "Approval complete" : "Approving token..."}</AlertTitle>
          </Alert>
          
          {/* Repayment step - only show if approval is complete */}
          {isApprovalStepComplete && (
            <Alert variant={isSuccess ? "success" : "default"} className={isSuccess ? "" : "animate-pulse"}>
              {isSuccess ? (
                <CheckCircle className="h-4 w-4 mr-2" />
              ) : (
                <Loader2 className="h-4 w-4 mr-2 animate-spin" />
              )}
              <AlertTitle>Step 2: {isSuccess ? "Repayment complete" : "Repaying debt..."}</AlertTitle>
              {isSuccess && txHash && (
                <AlertDescription>
                  <a 
                    href={`https://celoscan.io/tx/${txHash}`} 
                    target="_blank" 
                    rel="noopener noreferrer"
                    className="flex items-center text-green-600 hover:text-green-700"
                  >
                    <ExternalLink className="h-4 w-4 mr-2" />
                    View transaction
                  </a>
                </AlertDescription>
              )}
            </Alert>
          )}
          
          {isSuccess && (
            <div className="flex items-center text-sm gap-1 mt-2">
              <span>Redirecting to Positions page</span>
              <ArrowRight className="h-3 w-3 ml-1" />
            </div>
          )}
        </div>
      );
    }
    
    return null;
  };

  // Standard transaction status for other actions (not repayment)
  const renderTransactionStatus = (isLoading: boolean, isSuccess: boolean, error: Error | null, txHash: string | undefined, action: string) => {
    if (isLoading) {
      return (
        <Alert variant="default" className="mb-4 animate-pulse">
          <Loader2 className="h-4 w-4 mr-2 animate-spin" />
          <AlertTitle>Transaction in progress</AlertTitle>
          <AlertDescription>
            {action}...
          </AlertDescription>
        </Alert>
      );
    }
    
    if (isSuccess && txHash) {
      return (
        <Alert variant="success" className="mb-4">
          <CheckCircle className="h-4 w-4 mr-2" />
          <AlertTitle>Transaction successful!</AlertTitle>
          <AlertDescription>
            <a 
              href={`https://celoscan.io/tx/${txHash}`} 
              target="_blank" 
              rel="noopener noreferrer"
              className="flex items-center text-green-600 hover:text-green-700"
            >
              <ExternalLink className="h-4 w-4 mr-2" />
              View transaction
            </a>
          </AlertDescription>
        </Alert>
      );
    }
    
    if (error) {
      return (
        <Alert variant="destructive" className="mb-4">
          <AlertCircle className="h-4 w-4 mr-2" />
          <AlertTitle>Transaction failed</AlertTitle>
          <AlertDescription>
            {error.message || "Could not complete transaction. Please try again."}
          </AlertDescription>
        </Alert>
      );
    }
    
    return null;
  };

  // Add manual test function for direct contract interaction
  const testContractDirectly = async () => {
    if (!address || !publicClient) {
      console.error("Not connected");
      return;
    }
    
    console.log("=== DIRECT CONTRACT TEST ===");
    console.log("Connected address:", address);
    console.log("Contract address:", CONTRACT_ADDRESSES.lendyPositionManager);
    
    try {
      // Test getUserPositions
      console.log("Testing getUserPositions...");
      const positionIds = await publicClient.readContract({
        address: CONTRACT_ADDRESSES.lendyPositionManager,
        abi: LENDY_POSITION_MANAGER_ABI,
        functionName: 'getUserPositions',
        args: [address],
      }) as bigint[];
      console.log("Position IDs directly from contract:", positionIds);
      
      // Test getUserSupplyPositions
      console.log("Testing getUserSupplyPositions...");
      const supplyPositionIds = await publicClient.readContract({
        address: CONTRACT_ADDRESSES.lendyPositionManager,
        abi: LENDY_POSITION_MANAGER_ABI,
        functionName: 'getUserSupplyPositions',
        args: [address],
      }) as bigint[];
      console.log("Supply Position IDs directly from contract:", supplyPositionIds);
      
      // Check each supply position individually
      if (supplyPositionIds.length > 0) {
        console.log("DETAILED SUPPLY POSITION CHECK:");
        for (const id of supplyPositionIds) {
          try {
            console.log(`Checking supply position ${id}...`);
            const supplyData = await publicClient.readContract({
              address: CONTRACT_ADDRESSES.lendyPositionManager,
              abi: LENDY_POSITION_MANAGER_ABI,
              functionName: 'getSupplyPositionDetails',
              args: [id],
            });
            console.log(`Raw supply position ${id} data:`, supplyData);
            
            // Try direct reading from storage
            const directSupplyData = await publicClient.readContract({
              address: CONTRACT_ADDRESSES.lendyPositionManager,
              abi: LENDY_POSITION_MANAGER_ABI,
              functionName: 'supplyPositions',
              args: [id],
            });
            console.log(`Direct storage supply position ${id} data:`, directSupplyData);
          } catch (err) {
            console.error(`Error checking supply position ${id}:`, err);
          }
        }
      }
      
      // Get total counts from contract
      console.log("Testing totalActivePositions...");
      const totalActivePos = await publicClient.readContract({
        address: CONTRACT_ADDRESSES.lendyPositionManager,
        abi: LENDY_POSITION_MANAGER_ABI,
        functionName: 'totalActivePositions',
      }) as bigint;
      console.log("Total active positions from contract:", totalActivePos.toString());
      
      console.log("Testing totalActiveSupplyPositions...");
      const totalActiveSupplyPos = await publicClient.readContract({
        address: CONTRACT_ADDRESSES.lendyPositionManager,
        abi: LENDY_POSITION_MANAGER_ABI,
        functionName: 'totalActiveSupplyPositions',
      }) as bigint;
      console.log("Total active supply positions from contract:", totalActiveSupplyPos.toString());
      
    } catch (err) {
      console.error("Error in direct contract test:", err);
    }
  };

  // Handle supply position management
  const handleSupplyClick = (position: SupplyPosition) => {
    setSelectedPosition(position);
    setAdditionalAmount("");
    setModifyDialogOpen(true);
  };

  const handleWithdrawSupplyClick = (position: SupplyPosition) => {
    setSelectedPosition(position);
    setWithdrawAmount("");
    setWithdrawType("partial");
    setWithdrawDialogOpen(true);
  };

  // Calculate monthly yield for a supply position
  const calculateMonthlyYield = (position: SupplyPosition) => {
    if (!position.assetSymbol || !position.formattedAmount) return "0.00";
    
    const tokenKey = position.assetSymbol.toLowerCase() as keyof typeof SUPPLY_APY_RATES;
    const apy = SUPPLY_APY_RATES[tokenKey] || 0;
    const principal = parseFloat(position.formattedAmount);
    
    // Monthly yield = principal * (APY / 12)
    const monthly = principal * (apy / 100 / 12);
    return monthly.toFixed(6);
  };

  // Get APY for a supply position
  const getSupplyAPY = (symbol: string | undefined) => {
    if (!symbol) return "0%";
    const tokenKey = symbol.toLowerCase() as keyof typeof SUPPLY_APY_RATES;
    return `${SUPPLY_APY_RATES[tokenKey] || 0}%`;
  };

  // Handle opening the close dialog for supply positions
  const handleCloseSupplyClick = (position: SupplyPosition) => {
    setSelectedPosition(position);
    setCloseDialogOpen(true);
  };

  // Handle withdraw supply
  const handleWithdrawSupply = async () => {
    if (!selectedPosition?.supplyPositionId) return;
    
    try {
      // Get token decimals - assuming 6 for stablecoins if not available
      const decimals = selectedPosition.assetSymbol === "USDC" || selectedPosition.assetSymbol === "USDT" ? 6 : 18;
      
      await withdrawSupply(
        selectedPosition.supplyPositionId,
        withdrawAmount,
        decimals,
        withdrawType === "full"
      );
      
      // Close dialog after successful transaction
      if (isSupplyModified) {
        setWithdrawDialogOpen(false);
        
        // Trigger refresh after successful withdrawal
        setTimeout(() => {
          setRefreshTrigger(prev => prev + 1);
        }, 2000); // Wait for blockchain to process
      }
    } catch (err) {
      console.error("Error withdrawing supply:", err);
    }
  };

  return (
    <main className="min-h-screen bg-background text-foreground flex flex-col justify-between">
      <div className="container mx-auto px-4 py-8 flex-1 flex flex-col items-center">
        <div className="w-full max-w-xl">
          <h1 className="text-4xl font-bold mb-4" style={{ fontFamily: 'inherit', letterSpacing: '-1px' }}>Positions</h1>
          <div className="flex justify-between text-muted-foreground mb-6">
            <div className="flex flex-col items-center flex-1">
              <span className="text-sm">Total supplied</span>
              <span className="text-2xl font-bold text-foreground">{renderCurrency(totalSupplied)}</span>
            </div>
            <div className="flex flex-col items-center flex-1">
              <span className="text-sm">Total collateral</span>
              <span className="text-2xl font-bold text-foreground">{renderCurrency(totalCollateral)}</span>
            </div>
            <div className="flex flex-col items-center flex-1">
              <span className="text-sm">Total borrowed</span>
              <span className="text-2xl font-bold text-foreground">{renderCurrency(totalBorrowed)}</span>
            </div>
          </div>
          
          {/* Tabs for Earning/Borrowing */}
          <Tabs 
            defaultValue="earning" 
            className="w-full"
            onValueChange={handleTabChange}
          >
            <TabsList className="flex gap-4 bg-transparent p-0 mb-2 border-b border-border">
              <TabsTrigger value="earning" className="text-2xl font-bold px-0 py-2 mr-6 border-b-2 border-transparent data-[state=active]:border-foreground data-[state=active]:text-foreground" style={{ fontFamily: 'inherit', letterSpacing: '-1px' }}>
                Earning
              </TabsTrigger>
              <TabsTrigger value="borrowing" className="text-2xl font-bold px-0 py-2 mr-6 border-b-2 border-transparent data-[state=active]:border-foreground data-[state=active]:text-foreground" style={{ fontFamily: 'inherit', letterSpacing: '-1px' }}>
                Borrowing
              </TabsTrigger>
            </TabsList>
            
            {/* Loading State */}
            {(isPositionsLoading || isSupplyPositionsLoading) && (
              <div className="flex items-center justify-center p-10">
                <Loader2 className="h-8 w-8 animate-spin text-primary" />
                <span className="ml-2 text-muted-foreground">Loading positions...</span>
              </div>
            )}
            
            {/* Error State */}
            {(positionsError || supplyPositionsError) && (
              <Card className="bg-destructive/10 p-6 rounded-2xl text-center text-destructive my-4">
                <p>Failed to load positions: {positionsError?.message || supplyPositionsError?.message}</p>
                <p className="text-sm mt-2">Please try again later or contact support</p>
              </Card>
            )}
            
            {/* Not Connected State */}
            {!isConnected && !isPositionsLoading && !isSupplyPositionsLoading && (
              <Card className="bg-card p-6 rounded-2xl text-center text-muted-foreground">
                <p>Connect your wallet to view positions</p>
              </Card>
            )}
            
            {/* Connected but No Positions */}
            {isConnected && !isPositionsLoading && !isSupplyPositionsLoading && !positionsError && !supplyPositionsError && 
              ((currentTab === "earning" && supplyPositions.length === 0) || 
               (currentTab === "borrowing" && filteredPositions.length === 0)) && (
              <Card className="bg-card p-6 rounded-2xl text-center text-muted-foreground">
                {currentTab === "earning" ? (
                  <p>You have no active earning positions</p>
                ) :  (
                  <p>You have no active borrowing positions</p>
                ) }
              </Card>
            )}
            
            {/* Supply Positions List - Earning Tab */}
            <TabsContent value="earning">
              {/* Main Supply Positions Display */}
              {isConnected && !isSupplyPositionsLoading && !supplyPositionsError && (
                supplyPositions.length > 0 ? (
                  supplyPositions.map((position) => (
                    <Card key={position.supplyPositionId} className="bg-card p-6 rounded-2xl mb-4">
                      <span className="block text-xl mb-2">Aave Celo Pool</span>
                      <span className="block text-muted-foreground">Supplied: {position.assetSymbol}</span>
                      <div className="flex items-center gap-2 mt-2 mb-4">
                        <div className="h-8 w-8 bg-blue-100 dark:bg-blue-900 rounded-full flex items-center justify-center text-blue-500 font-bold">
                          {position.assetSymbol?.[0]}
                        </div>
                        <span className="text-2xl font-bold">{position.formattedAmount}</span>
                        <span className="text-muted-foreground">${position.formattedAmount}</span>
                      </div>
                      
                      <div className="mb-4">
                        <div className="flex items-center gap-2 mb-2">
                          <span className="text-muted-foreground">Supply APY</span>
                          <span className="text-lg font-semibold">
                            {getSupplyAPY(position.assetSymbol)}
                          </span>
                        </div>
                        <div className="flex items-center gap-2">
                          <span className="text-muted-foreground">Monthly yield</span>
                          <span className="text-lg font-semibold">
                            {calculateMonthlyYield(position)} {position.assetSymbol}
                          </span>
                        </div>
                      </div>
                      
                      <div className="flex gap-4 mt-2">
                        <Button 
                          variant="secondary" 
                          className="flex-1 bg-card border border-border text-foreground"
                          onClick={() => handleSupplyClick(position)}
                        >
                          Add Supply
                        </Button>
                        <Button 
                          variant="secondary" 
                          className="flex-1 bg-card border border-border text-foreground"
                          onClick={() => handleCloseSupplyClick(position)}
                        >
                          Withdraw
                        </Button>
                      </div>
                    </Card>
                  ))
                ) : (
                  <Card className="bg-card p-6 rounded-2xl text-center text-muted-foreground">
                    <p>You have no active earning positions</p>
                    <Button 
                      variant="outline" 
                      className="mt-4"
                      onClick={() => router.push('/earn')}
                    >
                      <Plus className="mr-2 h-4 w-4" />
                      Create supply position
                    </Button>
                  </Card>
                )
              )}
            </TabsContent>
            
            {/* Borrowing Positions List - Borrowing Tab */}
            <TabsContent value="borrowing">
              {isConnected && !isPositionsLoading && !positionsError && (
                filteredPositions.length > 0 ? (
                  filteredPositions.map((position) => (
                    <Card key={position.positionId} className="bg-card p-6 rounded-2xl mb-4">
                      <span className="block text-xl mb-2">Aave Celo Pool</span>
                      <div className="flex justify-between text-muted-foreground">
                        <div>
                          <span className="block font-medium">Borrowed</span>
                          <span className="block">{position.borrowAssetSymbol}</span>
                        </div>
                        <div>
                          <span className="block font-medium">Collateral</span>
                          <span className="block">{position.collateralAssetSymbol}</span>
                        </div>
                      </div>
                      <div className="flex items-center gap-2 mt-3 mb-4">
                        <div className="h-8 w-8 bg-blue-100 dark:bg-blue-900 rounded-full flex items-center justify-center text-blue-500 font-bold">
                          {position.borrowAssetSymbol?.[0]}
                        </div>
                        <span className="text-2xl font-bold">{position.formattedBorrowAmount}</span>
                        <span className="text-muted-foreground">${position.formattedBorrowAmount}</span>
                      </div>
                      <div className="mb-4">
                        <div className="flex items-center gap-2 mb-2">
                          <span className="text-muted-foreground">Borrow APY</span>
                          <span className="text-lg font-semibold">
                            1.2%
                          </span>
                        </div>
                        <div className="flex items-center gap-2">
                          <span className="text-muted-foreground">Collateral</span>
                          <span className="text-lg font-semibold">{position.formattedCollateralAmount} {position.collateralAssetSymbol}</span>
                        </div>
                        {__DEV__ && (
                          <div className="mt-2 text-xs text-muted-foreground border-t border-border pt-2">
                            <div>Borrow Asset: {position.borrowAsset.substring(0, 8)}...</div>
                            <div>Collateral Asset: {position.collateralAsset.substring(0, 8)}...</div>
                          </div>
                        )}
                      </div>
                      <div className="flex gap-4 mt-2">
                        <Button 
                          variant="secondary" 
                          className="flex-1 bg-card border border-border text-foreground"
                          onClick={() => handleModifyClick(position)}
                        >
                          Modify
                        </Button>
                        
                        {/* Check if the position has debt */}
                        {position.borrowAmount > BigInt(0) ? (
                          <Button 
                            variant="secondary" 
                            className="flex-1 bg-card border border-border text-foreground"
                            onClick={() => handleRepayClick(position)}
                          >
                            Repay
                          </Button>
                        ) : (
                          <Button 
                            variant="secondary" 
                            className="flex-1 bg-card border border-border text-foreground"
                            onClick={() => handleWithdrawClick(position)}
                          >
                            Withdraw
                          </Button>
                        )}
                      </div>
                      
                      {/* Show additional action if debt is fully repaid but collateral remains */}
                      {position.borrowAmount === BigInt(0) && position.collateralAmount > BigInt(0) && (
                        <div className="mt-4">
                          <Button 
                            variant="outline"
                            className="w-full text-green-600 border-green-600 hover:bg-green-50 dark:hover:bg-green-950"
                            onClick={() => handleWithdrawClick(position)}
                          >
                            Withdraw Collateral
                          </Button>
                          <p className="text-xs text-center mt-1 text-muted-foreground">
                            Your loan is fully repaid. You can withdraw your collateral now.
                          </p>
                        </div>
                      )}
                    </Card>
                  ))
                ) : (
                  <Card className="bg-card p-6 rounded-2xl text-center text-muted-foreground">
                    <p>You have no active borrowing positions</p>
                  </Card>
                )
              )}
            </TabsContent>
          </Tabs>
          
          {/* Celo Explorer Link */}
          {isConnected && address && (
            <div className="mt-6 text-center">
              <a 
                href={`https://celoscan.io/address/${address}`} 
                target="_blank" 
                rel="noopener noreferrer"
                className="text-primary flex items-center justify-center hover:text-primary/80"
              >
                <ExternalLink className="h-4 w-4 mr-2" />
                View all transactions on Celoscan
              </a>
            </div>
          )}
        </div>
      </div>
      
      {/* Add Collateral Dialog - Handle both regular and supply positions */}
      <Dialog open={modifyDialogOpen} onOpenChange={setModifyDialogOpen}>
        <DialogContent className="sm:max-w-[425px]">
          <DialogHeader>
            <DialogTitle>Add more {selectedPosition?.collateralAssetSymbol || selectedPosition?.assetSymbol}</DialogTitle>
            <DialogDescription>
              Add more funds to your position to increase your earning potential
            </DialogDescription>
          </DialogHeader>
          
          {renderTransactionStatus(
            isAddingCollateral || isSupplyModifying, 
            isAddSuccess || isSupplyModified, 
            addError || supplyModifyError, 
            addTxHash || supplyModifyTxHash, 
            "Adding funds"
          )}
          
          <div className="grid gap-4 py-4">
            <div className="grid gap-2">
              <Label htmlFor="amount">Amount</Label>
              <Input
                id="amount"
                placeholder="0.00"
                value={additionalAmount}
                onChange={(e) => setAdditionalAmount(e.target.value)}
                disabled={isAddingCollateral || isAddSuccess || isSupplyModifying || isSupplyModified}
              />
              <p className="text-xs text-muted-foreground">
                Current position: {
                  selectedPosition?.formattedCollateralAmount || 
                  selectedPosition?.formattedAmount
                } {
                  selectedPosition?.collateralAssetSymbol || 
                  selectedPosition?.assetSymbol
                }
              </p>
            </div>
          </div>
          <DialogFooter>
            <Button 
              variant="outline" 
              onClick={() => setModifyDialogOpen(false)}
              disabled={isAddingCollateral || isSupplyModifying}
            >
              Cancel
            </Button>
            <Button 
              onClick={selectedPosition?.supplyPositionId ? handleIncreaseSupply : handleAddCollateral}
              disabled={
                !additionalAmount || 
                parseFloat(additionalAmount) <= 0 || 
                isAddingCollateral || 
                isAddSuccess || 
                isSupplyModifying || 
                isSupplyModified
              }
            >
              {isAddingCollateral || isSupplyModifying ? (
                <>
                  <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                  Adding...
                </>
              ) : (
                <>
                  <Plus className="mr-2 h-4 w-4" />
                  Add Funds
                </>
              )}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
      
      {/* Close Position Dialog - Handle both regular and supply positions */}
      <Dialog open={closeDialogOpen} onOpenChange={setCloseDialogOpen}>
        <DialogContent className="sm:max-w-[425px]">
          <DialogHeader>
            <DialogTitle>Close Position</DialogTitle>
            <DialogDescription>
              Are you sure you want to close this position? All funds will be withdrawn.
            </DialogDescription>
          </DialogHeader>
          
          {renderTransactionStatus(
            isClosing || isSupplyModifying, 
            isCloseSuccess || isSupplyModified, 
            closeError || supplyModifyError, 
            closeTxHash || supplyModifyTxHash, 
            "Closing position"
          )}
          
          <div className="py-4">
            <div className="rounded-lg bg-muted p-4">
              <p className="font-medium">Position Details</p>
              <p className="text-sm text-muted-foreground mt-2">
                {selectedPosition?.supplyPositionId ? 'Supply' : 'Collateral'}: {
                  selectedPosition?.formattedCollateralAmount || 
                  selectedPosition?.formattedAmount
                } {
                  selectedPosition?.collateralAssetSymbol || 
                  selectedPosition?.assetSymbol
                }
              </p>
              {selectedPosition?.borrowAmount > 0 && (
                <p className="text-sm text-muted-foreground">Borrowed: {selectedPosition?.formattedBorrowAmount} {selectedPosition?.borrowAssetSymbol}</p>
              )}
            </div>
          </div>
          <DialogFooter>
            <Button 
              variant="outline" 
              onClick={() => setCloseDialogOpen(false)}
              disabled={isClosing || isSupplyModifying}
            >
              Cancel
            </Button>
            <Button 
              variant="destructive"
              onClick={selectedPosition?.supplyPositionId ? handleCloseSupplyPosition : handleClosePosition}
              disabled={isClosing || isCloseSuccess || isSupplyModifying || isSupplyModified}
            >
              {isClosing || isSupplyModifying ? (
                <>
                  <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                  Closing...
                </>
              ) : (
                "Close Position"
              )}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
      
      {/* Repay Debt Dialog */}
      <Dialog open={repayDialogOpen} onOpenChange={setRepayDialogOpen}>
        <DialogContent className="sm:max-w-[425px]">
          <DialogHeader>
            <DialogTitle>Repay Debt</DialogTitle>
            <DialogDescription>
              Choose how much of your debt you want to repay
            </DialogDescription>
          </DialogHeader>
          
          {/* Show emergency status if in emergency mode */}
          {isEmergencyClosing && (
            <Alert variant={isEmergencySuccess ? "success" : "default"} className={isEmergencySuccess ? "" : "animate-pulse"}>
              {isEmergencySuccess ? (
                <CheckCircle className="h-4 w-4 mr-2" />
              ) : (
                <Loader2 className="h-4 w-4 mr-2 animate-spin" />
              )}
              <AlertTitle>{isEmergencySuccess ? "Emergency Close Successful" : "Attempting Emergency Close..."}</AlertTitle>
              {isEmergencySuccess && emergencyTxHash && (
                <AlertDescription>
                  <a 
                    href={`https://celoscan.io/tx/${emergencyTxHash}`} 
                    target="_blank" 
                    rel="noopener noreferrer"
                    className="flex items-center text-green-600 hover:text-green-700"
                  >
                    <ExternalLink className="h-4 w-4 mr-2" />
                    View transaction
                  </a>
                </AlertDescription>
              )}
            </Alert>
          )}
          
          {/* Show normal repayment status if not in emergency mode */}
          {!isEmergencyClosing && renderRepaymentStatus(isRepaying, isRepaySuccess, isApprovalStepComplete, repayError, repayTxHash)}
          
          {/* Show special error handling for "NO_DEBT_OF_SELECTED_TYPE" */}
          {(repayError && repayError.message.includes('39')) || hadFailedRepayment ? (
            <Alert variant="warning" className="mb-4">
              <AlertCircle className="h-4 w-4 mr-2" />
              <AlertTitle>Repayment Failed</AlertTitle>
              <AlertDescription>
                <p>The position seems to have an error with the debt and cannot be repaid normally.</p>
                <p className="mt-2">Would you like to try an emergency close?</p>
                <Button 
                  variant="outline" 
                  className="mt-3 bg-amber-100 text-amber-800 border-amber-300 hover:bg-amber-200"
                  onClick={handleEmergencyClose}
                  disabled={isEmergencyClosing}
                >
                  {isEmergencyClosing ? (
                    <>
                      <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                      Attempting Emergency Close...
                    </>
                  ) : (
                    "Try Emergency Close"
                  )}
                </Button>
              </AlertDescription>
            </Alert>
          ) : null}
          
          <div className="grid gap-4 py-4">
            <div className="rounded-lg bg-muted p-4 mb-2">
              <p className="font-medium">Current Debt</p>
              <div className="flex justify-between items-center mt-1">
                <div>
                  <p className="text-sm text-muted-foreground">Borrowed Asset:</p>
                  <p className="text-lg font-semibold">
                    {selectedPosition?.borrowAssetSymbol || (borrowTokenSymbol ? borrowTokenSymbol.toUpperCase() : 'Unknown')}
                  </p>
                </div>
                <div>
                  <p className="text-sm text-muted-foreground">Amount:</p>
                  <p className="text-lg font-semibold">{selectedPosition?.formattedBorrowAmount}</p>
                </div>
              </div>
              <div className="border-t border-border my-2 pt-2">
                <p className="text-sm text-muted-foreground">Your wallet balance:</p>
                <p className="text-md">
                  {borrowTokenBalance} {borrowTokenSymbol ? borrowTokenSymbol.toUpperCase() : 'Unknown'}
                </p>
              </div>
              
              {/* Warning for tiny debt amounts */}
              {selectedPosition?.borrowAmount && selectedPosition.borrowAmount < BigInt(10000) && (
                <div className="mt-2 p-2 bg-amber-100 dark:bg-amber-900 rounded-md text-amber-800 dark:text-amber-200 text-xs">
                  <p className="font-medium">This is a very small debt amount</p>
                  <p>For tiny debts, we'll automatically close the position instead of repaying the specific amount.</p>
                </div>
              )}
              
              {!borrowTokenSymbol && (
                <p className="text-red-500 text-xs mt-1">
                  Error: Unable to determine borrow token type. 
                  <br />
                  Asset Address: {selectedPosition?.borrowAsset?.substring(0, 8)}...
                </p>
              )}
            </div>
            
            <RadioGroup 
              value={repayType} 
              onValueChange={(value) => setRepayType(value as "partial" | "full")}
              className="grid grid-cols-2 gap-4"
              disabled={isRepaying || isRepaySuccess || !borrowTokenSymbol}
            >
              <div>
                <RadioGroupItem
                  value="partial"
                  id="partial"
                  className="peer sr-only"
                  disabled={selectedPosition?.borrowAmount < BigInt(10000)}
                />
                <Label
                  htmlFor="partial"
                  className={`flex flex-col items-center justify-between rounded-md border-2 border-muted bg-popover p-4 hover:bg-accent hover:text-accent-foreground peer-data-[state=checked]:border-primary [&:has([data-state=checked])]:border-primary ${
                    selectedPosition?.borrowAmount < BigInt(10000) ? "opacity-50 cursor-not-allowed" : ""
                  }`}
                >
                  <span className="mb-1">Partial Repayment</span>
                  <span className="text-xs text-muted-foreground">Custom amount</span>
                </Label>
              </div>
              <div>
                <RadioGroupItem
                  value="full"
                  id="full"
                  className="peer sr-only"
                />
                <Label
                  htmlFor="full"
                  className="flex flex-col items-center justify-between rounded-md border-2 border-muted bg-popover p-4 hover:bg-accent hover:text-accent-foreground peer-data-[state=checked]:border-primary [&:has([data-state=checked])]:border-primary"
                >
                  <span className="mb-1">Full Repayment</span>
                  <span className="text-xs text-muted-foreground">Entire debt</span>
                </Label>
              </div>
            </RadioGroup>
            
            {repayType === "partial" && (
              <div className="grid gap-2">
                <Label htmlFor="repayAmount">Amount to repay</Label>
                <Input
                  id="repayAmount"
                  placeholder="0.00"
                  value={repayAmount}
                  onChange={(e) => setRepayAmount(e.target.value)}
                  disabled={isRepaying || isRepaySuccess || !borrowTokenSymbol || selectedPosition?.borrowAmount < BigInt(10000)}
                />
                {repayAmount && parseFloat(repayAmount) > parseFloat(borrowTokenBalance || "0") && (
                  <p className="text-red-500 text-xs">
                    Amount exceeds your wallet balance
                  </p>
                )}
                <div className="text-xs text-muted-foreground">
                  <p className="mt-1">
                    Note: You must repay with the same token type you borrowed ({borrowTokenSymbol ? borrowTokenSymbol.toUpperCase() : '?'})
                  </p>
                  {__DEV__ && (
                    <div className="mt-1 pt-1 border-t border-border text-xs">
                      <p>Debug Info:</p>
                      <p>Borrow Token: {borrowTokenSymbol || 'Not set'}</p>
                      <p>Asset Address: {selectedPosition?.borrowAsset ? selectedPosition.borrowAsset.substring(0, 10) + '...' : 'N/A'}</p>
                      <p>Position Symbol: {selectedPosition?.borrowAssetSymbol || 'N/A'}</p>
                      <p>Available Balance: {borrowTokenBalance}</p>
                    </div>
                  )}
                </div>
              </div>
            )}
          </div>
          <DialogFooter>
            <Button 
              variant="outline" 
              onClick={() => setRepayDialogOpen(false)}
              disabled={isRepaying || isEmergencyClosing}
            >
              Cancel
            </Button>
            <Button 
              onClick={handleRepayDebt}
              disabled={
                !borrowTokenSymbol ||
                (repayType === "partial" && (!repayAmount || parseFloat(repayAmount) <= 0 || parseFloat(repayAmount) > parseFloat(borrowTokenBalance || "0"))) ||
                isRepaying || 
                isRepaySuccess ||
                isEmergencyClosing ||
                hadFailedRepayment // Disable normal repay if we've already had a failure
              }
            >
              {isRepaying ? (
                <>
                  <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                  {isApprovalStepComplete ? 
                    (selectedPosition?.borrowAmount < BigInt(10000) || repayType === "full" ? "Closing..." : "Repaying...") : 
                    "Approving..."}
                </>
              ) : (
                selectedPosition?.borrowAmount < BigInt(10000) ? "Close Position" : `Repay ${repayType === "full" ? "All" : ""}`
              )}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
      
      {/* Withdraw Collateral Dialog */}
      <Dialog open={withdrawDialogOpen} onOpenChange={setWithdrawDialogOpen}>
        <DialogContent className="sm:max-w-[425px]">
          <DialogHeader>
            <DialogTitle>Withdraw {selectedPosition?.assetSymbol}</DialogTitle>
            <DialogDescription>
              Choose how much to withdraw from your supply position
            </DialogDescription>
          </DialogHeader>
          
          {renderTransactionStatus(
            isSupplyModifying, 
            isSupplyModified, 
            supplyModifyError, 
            supplyModifyTxHash, 
            "Withdrawing funds"
          )}
          
          <div className="grid gap-4 py-4">
            <div className="flex gap-2">
              <Button
                variant={withdrawType === "partial" ? "default" : "outline"}
                className="flex-1"
                onClick={() => setWithdrawType("partial")}
                disabled={isSupplyModifying || isSupplyModified}
              >
                Partial
              </Button>
              <Button
                variant={withdrawType === "full" ? "default" : "outline"}
                className="flex-1"
                onClick={() => setWithdrawType("full")}
                disabled={isSupplyModifying || isSupplyModified}
              >
                Full withdrawal
              </Button>
            </div>
            
            {withdrawType === "partial" && (
              <div className="grid gap-2">
                <Label htmlFor="withdrawAmount">Amount to withdraw</Label>
                <Input
                  id="withdrawAmount"
                  placeholder="0.00"
                  value={withdrawAmount}
                  onChange={(e) => setWithdrawAmount(e.target.value)}
                  disabled={isSupplyModifying || isSupplyModified}
                />
                <p className="text-xs text-muted-foreground">
                  Available to withdraw: {selectedPosition?.formattedAmount} {selectedPosition?.assetSymbol}
                </p>
              </div>
            )}
          </div>
          
          <DialogFooter>
            <Button 
              variant="outline" 
              onClick={() => setWithdrawDialogOpen(false)}
              disabled={isSupplyModifying}
            >
              Cancel
            </Button>
            <Button 
              onClick={handleWithdrawSupply}
              disabled={
                (withdrawType === "partial" && (!withdrawAmount || parseFloat(withdrawAmount) <= 0)) ||
                isSupplyModifying || 
                isSupplyModified
              }
            >
              {isSupplyModifying ? (
                <>
                  <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                  Withdrawing...
                </>
              ) : (
                "Withdraw"
              )}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </main>
  );
}