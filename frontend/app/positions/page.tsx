"use client";

import React, { useState, useEffect, useCallback } from "react";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/components/ui/tabs";
import { Info, Loader2, ExternalLink, Plus, CheckCircle, AlertCircle, ArrowRight } from "lucide-react";
import { useUserPositions } from "@/hooks/useUserPositions";
import { useAccount } from "wagmi";
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

// Debug flag - set to true to show extra debugging information in the UI
const __DEV__ = process.env.NODE_ENV === 'development';

export default function Positions() {
  const { isConnected, address } = useAccount();
  const router = useRouter();
  const { positions, isLoading, error, totalSupplied, totalCollateral, totalBorrowed } = useUserPositions();
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

  // Filter positions based on the current tab
  const filteredPositions = positions.filter(position => {
    if (currentTab === "earning") {
      // Only include positions with no borrow amount AND non-zero collateral
      return position.borrowAmount === BigInt(0) && position.collateralAmount > BigInt(0);
    }
    if (currentTab === "borrowing") {
      // Only borrow positions
      return position.borrowAmount > BigInt(0);
    }
    return false;
  });

  const handleTabChange = (value: string) => {
    setCurrentTab(value);
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
  
  // Handle adding collateral
  const handleAddCollateral = async () => {
    if (!selectedPosition || !additionalAmount || parseFloat(additionalAmount) <= 0) return;
    
    try {
      await addCollateral(
        selectedPosition.positionId, 
        additionalAmount,
        selectedPosition.collateralAssetSymbol || selectedPosition.assetSymbol
      );
    } catch (err) {
      console.error("Failed to add collateral:", err);
    }
  };
  
  // Handle closing position
  const handleClosePosition = async () => {
    if (!selectedPosition) return;
    
    try {
      await closePosition(selectedPosition.positionId);
    } catch (err) {
      console.error("Failed to close position:", err);
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
  
  // Effect to reset dialogs after successful transactions and redirect on repayment
  useEffect(() => {
    if (isAddSuccess || isCloseSuccess || isWithdrawSuccess) {
      setModifyDialogOpen(false);
      setCloseDialogOpen(false);
      setWithdrawDialogOpen(false);
      setSelectedPosition(null);
      setAdditionalAmount("");
      setWithdrawAmount("");
    }
    
    // For successful repayments, redirect to the Earning tab
    if (isRepaySuccess || isEmergencySuccess) {
      setRepayDialogOpen(false);
      setSelectedPosition(null);
      setRepayAmount("");
      setHadFailedRepayment(false); // Reset on success
      setCurrentTab("earning");
      
      // Give a small delay before redirecting to ensure state is properly updated
      setTimeout(() => {
        router.push("/positions");
      }, 500);
    }
  }, [isAddSuccess, isCloseSuccess, isRepaySuccess, isWithdrawSuccess, isEmergencySuccess, router]);

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
            {isLoading && (
              <div className="flex items-center justify-center p-10">
                <Loader2 className="h-8 w-8 animate-spin text-primary" />
                <span className="ml-2 text-muted-foreground">Loading positions...</span>
              </div>
            )}
            
            {/* Error State */}
            {error && (
              <Card className="bg-destructive/10 p-6 rounded-2xl text-center text-destructive my-4">
                <p>Failed to load positions: {error.message}</p>
                <p className="text-sm mt-2">Please try again later or contact support</p>
              </Card>
            )}
            
            {/* Not Connected State */}
            {!isConnected && !isLoading && (
              <Card className="bg-card p-6 rounded-2xl text-center text-muted-foreground">
                <p>Connect your wallet to view positions</p>
              </Card>
            )}
            
            {/* Connected but No Positions */}
            {isConnected && !isLoading && !error && filteredPositions.length === 0 && (
              <Card className="bg-card p-6 rounded-2xl text-center text-muted-foreground">
                {currentTab === "earning" ? (
                  <p>You have no active earning positions</p>
                ) :  (
                  <p>You have no active borrowing positions</p>
                ) }
              </Card>
            )}
            
            {/* Positions List */}
            <TabsContent value="earning">
              {isConnected && !isLoading && !error && filteredPositions.length > 0 && filteredPositions.map((position) => (
                <Card key={position.positionId} className="bg-card p-6 rounded-2xl mb-4">
                  <span className="block text-xl mb-2">Aave Celo Pool</span>
                  <span className="block text-muted-foreground">Supplied: {position.collateralAssetSymbol || position.assetSymbol}</span>
                  <div className="flex items-center gap-2 mt-2 mb-4">
                    <div className="h-8 w-8 bg-blue-100 dark:bg-blue-900 rounded-full flex items-center justify-center text-blue-500 font-bold">
                      {(position.collateralAssetSymbol || position.assetSymbol)?.[0]}
                    </div>
                    <span className="text-2xl font-bold">{position.formattedCollateralAmount}</span>
                    <span className="text-muted-foreground">${position.formattedCollateralAmount}</span>
                  </div>
                  <div className="mb-4">
                    <div className="flex items-center gap-2 mb-2">
                      <span className="text-muted-foreground">Supply APY</span>
                      <span className="text-lg font-semibold">
                        {(position.collateralAssetSymbol || position.assetSymbol) === 'USDC' ? '0.1%' : '0.01%'}
                      </span>
                      <span className="text-blue-400">✦</span>
                    </div>
                    <div className="flex items-center gap-2">
                      <span className="text-muted-foreground">Monthly yield</span>
                      <Info className="h-4 w-4 text-muted-foreground" />
                      <span className="text-lg font-semibold">
                        {(parseFloat(position.formattedCollateralAmount || '0') * 
                          ((position.collateralAssetSymbol || position.assetSymbol) === 'USDC' ? 0.1 : 0.01) / 100 / 12).toFixed(6)}
                      </span>
                      <span className="text-blue-400">✦</span>
                    </div>
                  </div>
                  <div className="flex gap-4 mt-2">
                    <Button 
                      variant="secondary" 
                      className="flex-1 bg-card border border-border text-foreground"
                      onClick={() => handleModifyClick(position)}
                    >
                      Modify
                    </Button>
                    <Button 
                      variant="secondary" 
                      className="flex-1 bg-card border border-border text-foreground"
                      onClick={() => handleCloseClick(position)}
                    >
                      Close
                    </Button>
                  </div>
                </Card>
              ))}
            </TabsContent>
            
            <TabsContent value="borrowing">
              {isConnected && !isLoading && !error && filteredPositions.length > 0 && filteredPositions.map((position) => (
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
                        {position.borrowAssetSymbol === 'USDC' ? '3.5%' : '3.2%'}
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
                    </div>
                  )}
                </Card>
              ))}
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
      
      {/* Add Collateral Dialog */}
      <Dialog open={modifyDialogOpen} onOpenChange={setModifyDialogOpen}>
        <DialogContent className="sm:max-w-[425px]">
          <DialogHeader>
            <DialogTitle>Add more {selectedPosition?.collateralAssetSymbol || selectedPosition?.assetSymbol}</DialogTitle>
            <DialogDescription>
              Add more funds to your position to increase your earning potential
            </DialogDescription>
          </DialogHeader>
          
          {renderTransactionStatus(isAddingCollateral, isAddSuccess, addError, addTxHash, "Adding collateral")}
          
          <div className="grid gap-4 py-4">
            <div className="grid gap-2">
              <Label htmlFor="amount">Amount</Label>
              <Input
                id="amount"
                placeholder="0.00"
                value={additionalAmount}
                onChange={(e) => setAdditionalAmount(e.target.value)}
                disabled={isAddingCollateral || isAddSuccess}
              />
              <p className="text-xs text-muted-foreground">
                Current position: {selectedPosition?.formattedCollateralAmount} {selectedPosition?.collateralAssetSymbol || selectedPosition?.assetSymbol}
              </p>
            </div>
          </div>
          <DialogFooter>
            <Button 
              variant="outline" 
              onClick={() => setModifyDialogOpen(false)}
              disabled={isAddingCollateral}
            >
              Cancel
            </Button>
            <Button 
              onClick={handleAddCollateral}
              disabled={!additionalAmount || parseFloat(additionalAmount) <= 0 || isAddingCollateral || isAddSuccess}
            >
              {isAddingCollateral ? (
                <>
                  <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                  Adding...
                </>
              ) : (
                <>
                  <Plus className="mr-2 h-4 w-4" />
                  Add Collateral
                </>
              )}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
      
      {/* Close Position Dialog */}
      <Dialog open={closeDialogOpen} onOpenChange={setCloseDialogOpen}>
        <DialogContent className="sm:max-w-[425px]">
          <DialogHeader>
            <DialogTitle>Close Position</DialogTitle>
            <DialogDescription>
              Are you sure you want to close this position? All collateral will be withdrawn.
            </DialogDescription>
          </DialogHeader>
          
          {renderTransactionStatus(isClosing, isCloseSuccess, closeError, closeTxHash, "Closing position")}
          
          <div className="py-4">
            <div className="rounded-lg bg-muted p-4">
              <p className="font-medium">Position Details</p>
              <p className="text-sm text-muted-foreground mt-2">Collateral: {selectedPosition?.formattedCollateralAmount} {selectedPosition?.collateralAssetSymbol || selectedPosition?.assetSymbol}</p>
              {selectedPosition?.borrowAmount > 0 && (
                <p className="text-sm text-muted-foreground">Borrowed: {selectedPosition?.formattedBorrowAmount} {selectedPosition?.borrowAssetSymbol}</p>
              )}
            </div>
          </div>
          <DialogFooter>
            <Button 
              variant="outline" 
              onClick={() => setCloseDialogOpen(false)}
              disabled={isClosing}
            >
              Cancel
            </Button>
            <Button 
              variant="destructive"
              onClick={handleClosePosition}
              disabled={isClosing || isCloseSuccess}
            >
              {isClosing ? (
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
                      <p>Asset Address: {selectedPosition?.borrowAsset.substring(0, 10)}...</p>
                      <p>Position Symbol: {selectedPosition?.borrowAssetSymbol}</p>
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
            <DialogTitle>Withdraw Collateral</DialogTitle>
            <DialogDescription>
              Choose how much collateral you want to withdraw
            </DialogDescription>
          </DialogHeader>
          
          {renderTransactionStatus(isWithdrawing, isWithdrawSuccess, withdrawError, withdrawTxHash, "Withdrawing collateral")}
          
          <div className="grid gap-4 py-4">
            <div className="rounded-lg bg-muted p-4 mb-2">
              <p className="font-medium">Available Collateral</p>
              <div className="flex justify-between items-center mt-1">
                <div>
                  <p className="text-sm text-muted-foreground">Collateral Asset:</p>
                  <p className="text-lg font-semibold">
                    {selectedPosition?.collateralAssetSymbol || selectedPosition?.assetSymbol}
                  </p>
                </div>
                <div>
                  <p className="text-sm text-muted-foreground">Amount:</p>
                  <p className="text-lg font-semibold">{selectedPosition?.formattedCollateralAmount}</p>
                </div>
              </div>
              
              {/* Show if there's still debt */}
              {selectedPosition?.borrowAmount > 0 && (
                <div className="mt-2 p-2 bg-yellow-100 dark:bg-yellow-900 rounded-md text-yellow-800 dark:text-yellow-200 text-xs">
                  <p className="font-medium">Warning: You still have outstanding debt</p>
                  <p>You must pay off your debt first before withdrawing all collateral.</p>
                </div>
              )}
            </div>
            
            <RadioGroup 
              value={withdrawType} 
              onValueChange={(value) => setWithdrawType(value as "partial" | "full")}
              className="grid grid-cols-2 gap-4"
              disabled={isWithdrawing || isWithdrawSuccess}
            >
              <div>
                <RadioGroupItem
                  value="partial"
                  id="partial-withdraw"
                  className="peer sr-only"
                />
                <Label
                  htmlFor="partial-withdraw"
                  className="flex flex-col items-center justify-between rounded-md border-2 border-muted bg-popover p-4 hover:bg-accent hover:text-accent-foreground peer-data-[state=checked]:border-primary [&:has([data-state=checked])]:border-primary"
                >
                  <span className="mb-1">Partial Withdrawal</span>
                  <span className="text-xs text-muted-foreground">Custom amount</span>
                </Label>
              </div>
              <div>
                <RadioGroupItem
                  value="full"
                  id="full-withdraw"
                  className="peer sr-only"
                />
                <Label
                  htmlFor="full-withdraw"
                  className="flex flex-col items-center justify-between rounded-md border-2 border-muted bg-popover p-4 hover:bg-accent hover:text-accent-foreground peer-data-[state=checked]:border-primary [&:has([data-state=checked])]:border-primary"
                >
                  <span className="mb-1">Full Withdrawal</span>
                  <span className="text-xs text-muted-foreground">All collateral</span>
                </Label>
              </div>
            </RadioGroup>
            
            {withdrawType === "partial" && (
              <div className="grid gap-2">
                <Label htmlFor="withdrawAmount">Amount to withdraw</Label>
                <Input
                  id="withdrawAmount"
                  placeholder="0.00"
                  value={withdrawAmount}
                  onChange={(e) => setWithdrawAmount(e.target.value)}
                  disabled={isWithdrawing || isWithdrawSuccess}
                />
                {withdrawAmount && parseFloat(withdrawAmount) > parseFloat(selectedPosition?.formattedCollateralAmount || "0") && (
                  <p className="text-red-500 text-xs">
                    Amount exceeds available collateral
                  </p>
                )}
                <p className="text-xs text-muted-foreground">
                  Note: You will receive {selectedPosition?.collateralAssetSymbol || selectedPosition?.assetSymbol} in your wallet
                </p>
              </div>
            )}
          </div>
          <DialogFooter>
            <Button 
              variant="outline" 
              onClick={() => setWithdrawDialogOpen(false)}
              disabled={isWithdrawing}
            >
              Cancel
            </Button>
            <Button 
              onClick={handleWithdrawCollateral}
              disabled={
                (withdrawType === "partial" && (!withdrawAmount || parseFloat(withdrawAmount) <= 0 || parseFloat(withdrawAmount) > parseFloat(selectedPosition?.formattedCollateralAmount || "0"))) ||
                isWithdrawing || 
                isWithdrawSuccess
              }
            >
              {isWithdrawing ? (
                <>
                  <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                  Withdrawing...
                </>
              ) : (
                `Withdraw ${withdrawType === "full" ? "All" : ""}`
              )}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </main>
  );
}