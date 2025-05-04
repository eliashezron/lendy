"use client";

import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Select, SelectTrigger, SelectValue, SelectContent, SelectItem } from "@/components/ui/select";
import { Input } from "@/components/ui/input";
import { Info, ChevronDown, ChevronUp, Loader2, CheckCircle, AlertCircle, ExternalLink, ArrowRight } from "lucide-react";
import { useState, useEffect, ChangeEvent } from "react";
import { useAccount } from "wagmi";
import { useRouter } from "next/navigation";
import { useTokenBalance } from "@/hooks/useTokenBalance";
import { Alert, AlertTitle, AlertDescription } from "@/components/ui/alert";
import { TokenIcon } from "@/components/token-icon"; 
import { useCreatePosition, PositionMode } from "@/hooks/useCreatePosition";

// Supply APY rates from Aave
const SUPPLY_APY_RATES = {
  usdc: 0.1, // 0.1%
  usdt: 0.01, // 0.01%
};

// Borrow APY rates from Aave
const BORROW_APY_RATES = {
  usdc: 3.5, // 3.5%
  usdt: 3.2, // 3.2%
};

export default function Borrow() {
  // UI state
  const [detailsOpen, setDetailsOpen] = useState(true);
  
  // Collateral state
  const [collateralToken, setCollateralToken] = useState<string | null>(null);
  const [collateralAmount, setCollateralAmount] = useState("0.00");
  const [collateralPercentage, setCollateralPercentage] = useState<string | null>(null);
  
  // Borrow state
  const [borrowToken, setBorrowToken] = useState<string | null>(null);
  const [borrowAmount, setBorrowAmount] = useState("0.00");
  const [borrowPercentage, setBorrowPercentage] = useState<string | null>(null);
  
  // Hook state
  const { isConnected, address } = useAccount();
  const router = useRouter();
  const { createPosition, isLoading, isSuccess, error, txHash } = useCreatePosition();
  
  // Get token balances
  const { 
    balance: collateralBalance, 
    rawBalance: collateralRawBalance, 
    decimals: collateralDecimals 
  } = useTokenBalance(collateralToken);
  
  const { 
    balance: borrowBalance, 
    rawBalance: borrowRawBalance, 
    decimals: borrowDecimals 
  } = useTokenBalance(borrowToken);

  // Calculate max borrow amount (70% of collateral value for safety)
  const calculateMaxBorrow = () => {
    if (!collateralAmount || collateralAmount === "0.00") return "0.00";
    const collateralValue = parseFloat(collateralAmount);
    // For simplicity, assume 1:1 exchange rate between stablecoins
    return (collateralValue * 0.7).toFixed(2);
  };

  // Handle collateral token selection
  const handleCollateralTokenChange = (value: string) => {
    setCollateralToken(value);
    // Reset amount when token changes
    setCollateralAmount("0.00");
    setCollateralPercentage(null);
  };

  // Handle borrow token selection
  const handleBorrowTokenChange = (value: string) => {
    setBorrowToken(value);
    // Reset amount when token changes
    setBorrowAmount("0.00");
    setBorrowPercentage(null);
  };

  // Handle collateral amount change
  const handleCollateralAmountChange = (e: ChangeEvent<HTMLInputElement>) => {
    setCollateralPercentage(null);
    
    const value = e.target.value;
    // Allow only numbers and decimal point
    if (/^(\d*\.?\d*)$/.test(value) || value === '') {
      setCollateralAmount(value === '' ? '0.00' : value);
    }
  };

  // Handle borrow amount change
  const handleBorrowAmountChange = (e: ChangeEvent<HTMLInputElement>) => {
    setBorrowPercentage(null);
    
    const value = e.target.value;
    // Allow only numbers and decimal point
    if (/^(\d*\.?\d*)$/.test(value) || value === '') {
      setBorrowAmount(value === '' ? '0.00' : value);
    }
  };

  // Handle collateral percentage selection
  const handleCollateralPercentage = (percentage: string) => {
    setCollateralPercentage(percentage);
    
    // Calculate amount based on the selected percentage of user's balance
    if (collateralBalance && collateralBalance !== "0.00") {
      const numericBalance = parseFloat(collateralBalance);
      const percentValue = parseInt(percentage.replace("%", ""));
      const calculatedAmount = (numericBalance * percentValue / 100).toFixed(2);
      setCollateralAmount(calculatedAmount);
    } else {
      setCollateralAmount("0.00");
    }
  };

  // Handle borrow percentage selection
  const handleBorrowPercentage = (percentage: string) => {
    setBorrowPercentage(percentage);
    
    // Calculate amount based on the selected percentage of max borrowing capacity
    const maxBorrow = calculateMaxBorrow();
    if (maxBorrow !== "0.00") {
      const numericMaxBorrow = parseFloat(maxBorrow);
      const percentValue = parseInt(percentage.replace("%", ""));
      const calculatedAmount = (numericMaxBorrow * percentValue / 100).toFixed(2);
      setBorrowAmount(calculatedAmount);
    } else {
      setBorrowAmount("0.00");
    }
  };

  // Update max borrow amount when collateral amount changes
  useEffect(() => {
    if (borrowPercentage && borrowPercentage !== null) {
      handleBorrowPercentage(borrowPercentage);
    }
  }, [collateralAmount]);

  // Validate inputs
  const isCollateralValid = () => {
    if (!collateralBalance || collateralBalance === "0.00") return false;
    if (!collateralAmount || collateralAmount === "0.00") return false;
    
    const numericAmount = parseFloat(collateralAmount);
    const numericBalance = parseFloat(collateralBalance);
    
    // Minimum amount is 0.1 tokens
    return numericAmount >= 0.1 && numericAmount <= numericBalance;
  };

  const isBorrowValid = () => {
    if (!borrowAmount || borrowAmount === "0.00") return false;
    
    const numericAmount = parseFloat(borrowAmount);
    const maxBorrow = parseFloat(calculateMaxBorrow());
    
    // Borrow amount must be positive and not exceed max borrowing capacity
    return numericAmount > 0 && numericAmount <= maxBorrow;
  };

  const isFormValid = () => {
    return isCollateralValid() && isBorrowValid() && collateralToken !== null && borrowToken !== null;
  };

  // Get error messages
  const getCollateralErrorMessage = () => {
    if (!collateralToken || collateralAmount === "0.00") return null;
    
    const numericAmount = parseFloat(collateralAmount);
    const numericBalance = parseFloat(collateralBalance || "0");
    
    if (numericAmount < 0.1) {
      return `Minimum collateral is 0.1 ${collateralToken.toUpperCase()}`;
    }
    
    if (numericAmount > numericBalance) {
      return "Amount exceeds balance";
    }
    
    return null;
  };

  const getBorrowErrorMessage = () => {
    if (!borrowToken || borrowAmount === "0.00") return null;
    
    const numericAmount = parseFloat(borrowAmount);
    const maxBorrow = parseFloat(calculateMaxBorrow());
    
    if (numericAmount <= 0) {
      return "Borrow amount must be greater than 0";
    }
    
    if (numericAmount > maxBorrow) {
      return "Amount exceeds maximum borrowing capacity";
    }
    
    return null;
  };

  // Calculate APY rates
  const getSupplyAPY = () => {
    if (!collateralToken) return "N/A";
    return `${SUPPLY_APY_RATES[collateralToken as keyof typeof SUPPLY_APY_RATES] || 0}%`;
  };

  const getBorrowAPY = () => {
    if (!borrowToken) return "N/A";
    return `${BORROW_APY_RATES[borrowToken as keyof typeof BORROW_APY_RATES] || 0}%`;
  };

  // Calculate monthly costs/yields
  const getMonthlyCost = () => {
    if (!borrowToken || borrowAmount === "0.00") return "N/A";
    
    const principal = parseFloat(borrowAmount);
    const apr = BORROW_APY_RATES[borrowToken as keyof typeof BORROW_APY_RATES] || 0;
    // Monthly cost = principal * (APR / 12)
    const monthly = principal * (apr / 100 / 12);
    
    return `${monthly.toFixed(4)} ${borrowToken.toUpperCase()}`;
  };

  const getMonthlyYield = () => {
    if (!collateralToken || collateralAmount === "0.00") return "N/A";
    
    const principal = parseFloat(collateralAmount);
    const apy = SUPPLY_APY_RATES[collateralToken as keyof typeof SUPPLY_APY_RATES] || 0;
    // Monthly yield = principal * (APY / 12)
    const monthly = principal * (apy / 100 / 12);
    
    return `${monthly.toFixed(4)} ${collateralToken.toUpperCase()}`;
  };

  // Calculate LTV (Loan-to-Value)
  const calculateLTV = () => {
    if (!collateralAmount || collateralAmount === "0.00" || !borrowAmount || borrowAmount === "0.00") {
      return "N/A";
    }
    
    const collateralValue = parseFloat(collateralAmount);
    const borrowValue = parseFloat(borrowAmount);
    
    // For simplicity, assume 1:1 exchange rate between stablecoins
    const ltv = (borrowValue / collateralValue) * 100;
    
    return `${ltv.toFixed(2)}%`;
  };

  // Handle position creation
  const handleCreatePosition = async () => {
    if (!isFormValid() || !isConnected) return;
    
    try {
      console.log(`Creating position with ${collateralAmount} ${collateralToken} as collateral and borrowing ${borrowAmount} ${borrowToken}`);
      
      await createPosition(
        collateralToken!, 
        collateralAmount, 
        collateralDecimals,
        PositionMode.BORROW,
        {
          borrowAsset: borrowToken!,
          borrowAmount: borrowAmount,
          borrowDecimals: borrowDecimals
        }
      );
    } catch (err) {
      console.error("Failed to create position:", err);
    }
  };

  // Navigate to positions page
  const navigateToPositions = () => {
    router.push('/positions');
  };

  // Render transaction status
  const renderTransactionStatus = () => {
    if (isLoading) {
      return (
        <Alert variant="default" className="mb-4 animate-pulse">
          <Loader2 className="h-4 w-4 mr-2 animate-spin" />
          <AlertTitle>Transaction in progress</AlertTitle>
          <AlertDescription>
            Creating your position...
          </AlertDescription>
        </Alert>
      );
    }
    
    if (isSuccess || txHash) {
      return (
        <Alert variant="success" className="mb-4">
          <CheckCircle className="h-4 w-4 mr-2" />
          <AlertTitle>Position created!</AlertTitle>
          <AlertDescription>
            Your borrow position has been successfully created.
            <div className="mt-4 flex flex-col space-y-2">
              {txHash && (
                <a 
                  href={`https://celoscan.io/tx/${txHash}`} 
                  target="_blank" 
                  rel="noopener noreferrer"
                  className="flex items-center text-green-600 hover:text-green-700"
                >
                  <ExternalLink className="h-4 w-4 mr-2" />
                  View transaction
                </a>
              )}
              <Button 
                variant="outline" 
                size="sm" 
                className="mt-2 flex items-center border-green-500 text-green-600 hover:text-green-700"
                onClick={navigateToPositions}
              >
                View your positions
                <ArrowRight className="h-4 w-4 ml-2" />
              </Button>
            </div>
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
            {error.message || "Could not create position. Please try again."}
          </AlertDescription>
        </Alert>
      );
    }
    
    return null;
  };

  return (
    <main className="min-h-screen bg-background text-foreground flex flex-col justify-between">
      <div className="container mx-auto px-2 py-6 flex-1 flex flex-col items-center justify-center">
        <div className="w-full max-w-md flex flex-col gap-6">
          {renderTransactionStatus()}
          
          {/* Deposit Card */}
          <Card className="bg-card p-4 rounded-2xl mb-2">
            <span className="block text-muted-foreground mb-2">I will deposit</span>
            <div className="bg-muted rounded-xl p-4 flex flex-col gap-2">
              <div className="flex items-center justify-between mb-2">
                <Input
                  type="text"
                  value={collateralAmount}
                  onChange={handleCollateralAmountChange}
                  className="text-3xl font-semibold border-none bg-transparent p-0 h-auto text-left w-[60%] focus-visible:ring-0 focus-visible:ring-offset-0"
                  placeholder="0.00"
                  disabled={isLoading || isSuccess}
                />
                <Select 
                  value={collateralToken || ''}
                  onValueChange={handleCollateralTokenChange}
                  disabled={isLoading || isSuccess}
                >
                  <SelectTrigger className="w-40 bg-muted text-foreground border-none focus:ring-0">
                    <SelectValue placeholder="Choose asset" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="usdc">USDC</SelectItem>
                    <SelectItem value="usdt">USDT</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              {isConnected && collateralToken ? (
                <p className="text-muted-foreground text-sm mb-2">Balance: {collateralBalance} {collateralToken.toUpperCase()}</p>
              ) : (
                <p className="text-muted-foreground text-sm mb-2">Select a token</p>
              )}
              {getCollateralErrorMessage() && (
                <p className="text-red-500 text-sm">{getCollateralErrorMessage()}</p>
              )}
              <div className="grid grid-cols-2 gap-2 mt-2">
                <Button 
                  variant={collateralPercentage === "25%" ? "default" : "secondary"}
                  className="w-full bg-card border border-border text-foreground"
                  onClick={() => handleCollateralPercentage("25%")}
                  disabled={!isConnected || !collateralToken || collateralBalance === "0.00" || isLoading || isSuccess}
                >
                  25%
                </Button>
                <Button 
                  variant={collateralPercentage === "50%" ? "default" : "secondary"}
                  className="w-full bg-card border border-border text-foreground"
                  onClick={() => handleCollateralPercentage("50%")}
                  disabled={!isConnected || !collateralToken || collateralBalance === "0.00" || isLoading || isSuccess}
                >
                  50%
                </Button>
                <Button 
                  variant={collateralPercentage === "75%" ? "default" : "secondary"}
                  className="w-full bg-card border border-border text-foreground"
                  onClick={() => handleCollateralPercentage("75%")}
                  disabled={!isConnected || !collateralToken || collateralBalance === "0.00" || isLoading || isSuccess}
                >
                  75%
                </Button>
                <Button 
                  variant={collateralPercentage === "100%" ? "default" : "secondary"}
                  className="w-full bg-card border border-border text-foreground"
                  onClick={() => handleCollateralPercentage("100%")}
                  disabled={!isConnected || !collateralToken || collateralBalance === "0.00" || isLoading || isSuccess}
                >
                  100%
                </Button>
              </div>
            </div>
          </Card>

          {/* Borrow Card */}
          <Card className="bg-card p-4 rounded-2xl mb-2">
            <span className="block text-muted-foreground mb-2">To borrow</span>
            <div className="bg-muted rounded-xl p-4 flex flex-col gap-2">
              <div className="flex items-center justify-between mb-2">
                <Input
                  type="text"
                  value={borrowAmount}
                  onChange={handleBorrowAmountChange}
                  className="text-3xl font-semibold border-none bg-transparent p-0 h-auto text-left w-[60%] focus-visible:ring-0 focus-visible:ring-offset-0"
                  placeholder="0.00"
                  disabled={isLoading || isSuccess}
                />
                <Select 
                  value={borrowToken || ''}
                  onValueChange={handleBorrowTokenChange}
                  disabled={isLoading || isSuccess}
                >
                  <SelectTrigger className="w-40 bg-muted text-foreground border-none focus:ring-0">
                    <SelectValue placeholder="Choose asset" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="usdc">USDC</SelectItem>
                    <SelectItem value="usdt">USDT</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <p className="text-muted-foreground text-sm mb-2">
                Max borrow: {calculateMaxBorrow()} {borrowToken?.toUpperCase() || ''}
              </p>
              {getBorrowErrorMessage() && (
                <p className="text-red-500 text-sm">{getBorrowErrorMessage()}</p>
              )}
              <div className="w-full h-1 bg-border rounded-full my-2" />
              <div className="grid grid-cols-2 gap-2 mt-2">
                <Button 
                  variant={borrowPercentage === "25%" ? "default" : "secondary"}
                  className="w-full bg-card border border-border text-foreground"
                  onClick={() => handleBorrowPercentage("25%")}
                  disabled={!collateralToken || collateralAmount === "0.00" || !borrowToken || isLoading || isSuccess}
                >
                  25%
                </Button>
                <Button 
                  variant={borrowPercentage === "50%" ? "default" : "secondary"}
                  className="w-full bg-card border border-border text-foreground"
                  onClick={() => handleBorrowPercentage("50%")}
                  disabled={!collateralToken || collateralAmount === "0.00" || !borrowToken || isLoading || isSuccess}
                >
                  50%
                </Button>
                <Button 
                  variant={borrowPercentage === "75%" ? "default" : "secondary"}
                  className="w-full bg-card border border-border text-foreground"
                  onClick={() => handleBorrowPercentage("75%")}
                  disabled={!collateralToken || collateralAmount === "0.00" || !borrowToken || isLoading || isSuccess}
                >
                  75%
                </Button>
                <Button 
                  variant={borrowPercentage === "90%" ? "default" : "secondary"}
                  className="w-full bg-card border border-border text-foreground"
                  onClick={() => handleBorrowPercentage("90%")}
                  disabled={!collateralToken || collateralAmount === "0.00" || !borrowToken || isLoading || isSuccess}
                >
                  90%
                </Button>
              </div>
            </div>
          </Card>

          {/* Overview Card */}
          <Card className="bg-card p-4 rounded-2xl mb-2">
            <span className="block text-muted-foreground mb-2">Overview</span>
            <div className="bg-muted rounded-xl p-4">
              <div className="flex flex-col md:flex-row gap-4 mb-4">
                <div className="flex-1">
                  <span className="block text-lg font-semibold mb-1">Pool</span>
                  <div className="flex justify-between text-muted-foreground">
                    <div>
                      <span className="block font-semibold">Debt</span>
                      <div className="flex items-center gap-2 mt-1">
                        {borrowToken && (
                          <>
                            <TokenIcon symbol={borrowToken} />
                            <span className="text-xl font-bold">{borrowAmount}</span>
                            <span className="text-muted-foreground text-xs">${borrowAmount}</span>
                          </>
                        )}
                      </div>
                    </div>
                    <div>
                      <span className="block font-semibold">Collateral</span>
                      <div className="flex items-center gap-2 mt-1">
                        {collateralToken && (
                          <>
                            <TokenIcon symbol={collateralToken} />
                            <span className="text-xl font-bold">{collateralAmount}</span>
                            <span className="text-muted-foreground text-xs">${collateralAmount}</span>
                          </>
                        )}
                      </div>
                    </div>
                  </div>
                </div>
              </div>
              <div className="flex flex-col md:flex-row gap-4 mb-4">
                <div className="flex-1">
                  <div className="flex justify-between text-muted-foreground">
                    <span>Borrow APR <Info className="inline h-4 w-4 ml-1" /></span>
                    <span>{getBorrowAPY()}</span>
                  </div>
                  <div className="flex justify-between text-muted-foreground mt-2">
                    <span>Monthly cost</span>
                    <span>{getMonthlyCost()}</span>
                  </div>
                </div>
                <div className="flex-1">
                  <div className="flex justify-between text-muted-foreground">
                    <span>Supply APY</span>
                    <span>{getSupplyAPY()}</span>
                  </div>
                  <div className="flex justify-between text-muted-foreground mt-2">
                    <span>Monthly yield <Info className="inline h-4 w-4 ml-1" /></span>
                    <span>{getMonthlyYield()}</span>
                  </div>
                </div>
              </div>
              <div className="flex flex-col gap-2 mb-2">
                <span className="text-muted-foreground">Loan-to-value</span>
                <span className="text-2xl font-bold">{calculateLTV()}</span>
              </div>
              <button
                className="w-full border border-primary/50 rounded-lg py-2 text-primary flex items-center justify-center gap-2 mb-4 bg-transparent"
                onClick={() => setDetailsOpen((v) => !v)}
                disabled={isLoading || isSuccess}
              >
                More details {detailsOpen ? <ChevronUp className="h-4 w-4" /> : <ChevronDown className="h-4 w-4" />}
              </button>
              {detailsOpen && (
                <div className="bg-background rounded-lg p-4 mb-4">
                  <div className="flex justify-between text-muted-foreground mb-2">
                    <span>Market</span>
                    <span>Aave Celo Markets</span>
                    <span className="flex items-center gap-1">Market fee <Info className="h-4 w-4" /> <span>0%</span></span>
                  </div>
                  <div className="flex justify-between text-muted-foreground mb-2">
                    <span>LTV</span>
                    <span>0% → {calculateLTV()}</span>
                  </div>
                  <div className="flex justify-between text-muted-foreground mb-2">
                    <span>Supplied asset</span>
                    <span>0 → {collateralAmount} {collateralToken?.toUpperCase() || ''}</span>
                  </div>
                  <div className="flex justify-between text-muted-foreground mb-2">
                    <span>Debt</span>
                    <span>0 → {borrowAmount} {borrowToken?.toUpperCase() || ''}</span>
                  </div>
                  <div className="flex justify-between text-muted-foreground mb-2">
                    <span>Supply APY</span>
                    <span>{getSupplyAPY()}</span>
                  </div>
                  <div className="flex justify-between text-muted-foreground">
                    <span>Borrow APR</span>
                    <span>{getBorrowAPY()}</span>
                  </div>
                </div>
              )}
            </div>
          </Card>

          <Button 
            className="w-full bg-primary text-primary-foreground text-lg py-4 mt-2"
            disabled={!isFormValid() || !isConnected || isLoading || isSuccess}
            onClick={handleCreatePosition}
          >
            {isLoading ? (
              <>
                <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                Creating Position...
              </>
            ) : (
              "Borrow"
            )}
          </Button>
          
          {!isConnected && (
            <p className="text-center text-sm text-muted-foreground mt-2">
              Connect your wallet to create a position
            </p>
          )}
        </div>
      </div>
      <div className="container mx-auto px-4 pb-6">
        <div className="text-center">
          <p className="mb-4 text-sm sm:text-base text-muted-foreground px-4">
            Lendy is a fully open, transparent and secure crypto lending protocol built on Celo.
          </p>
        </div>
      </div>
    </main>
  );
}