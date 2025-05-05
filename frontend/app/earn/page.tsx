"use client";

import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { useState, useEffect, ChangeEvent, useMemo } from "react";
import { Info, ChevronDown, ChevronUp, Plus, Loader2, CheckCircle, AlertCircle, ExternalLink, ArrowRight } from "lucide-react";
import { 
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue
} from "@/components/ui/select";
import { TokenIcon } from "@/components/token-icon";
import { useTokenBalance } from "@/hooks/useTokenBalance";
import { useAccount } from "wagmi";
import { useRouter } from "next/navigation";
import { Input } from "@/components/ui/input"; 
import { useSupplyPosition } from "@/hooks/useSupplyPosition";
import { Alert, AlertTitle, AlertDescription } from "@/components/ui/alert";

// Supply APY rates from Aave
const SUPPLY_APY_RATES = {
  usdc: 0.1, // 0.1%
  usdt: 0.01, // 0.01%
};

export default function Earn() {
  const [detailsOpen, setDetailsOpen] = useState(false);
  const [overviewOpen, setOverviewOpen] = useState(false);
  const [amount, setAmount] = useState("0.00");
  const [selectedPercentage, setSelectedPercentage] = useState<string | null>(null);
  const [selectedToken, setSelectedToken] = useState<string | null>(null);
  const { balance, rawBalance, decimals, isMiniPay, refetch: refetchBalance } = useTokenBalance(selectedToken);
  const { isConnected } = useAccount();
  const router = useRouter();
  const { 
    createSupplyPosition, 
    isLoading, 
    isSuccess, 
    error, 
    txHash,
    isApprovalStepComplete,
    approvalTxHash,
  } = useSupplyPosition();
  
  // Reset form after successful transaction
  useEffect(() => {
    if (isSuccess) {
      // If you want to automatically reset the form after success
      // setAmount("0.00");
      // setSelectedPercentage(null);
    }
  }, [isSuccess]);

  // Get current APY based on selected token
  const currentApy = useMemo(() => {
    if (!selectedToken) return null;
    return SUPPLY_APY_RATES[selectedToken as keyof typeof SUPPLY_APY_RATES] || null;
  }, [selectedToken]);

  // Calculate estimated monthly yield
  const monthlyYield = useMemo(() => {
    if (!currentApy || !amount || amount === "0.00") return "0.00";
    const principal = parseFloat(amount);
    // Monthly yield = principal * (APY / 12)
    const monthly = principal * (currentApy / 100 / 12);
    return monthly.toFixed(6);
  }, [currentApy, amount]);

  // Update amount when balance changes
  useEffect(() => {
    if (selectedPercentage) {
      handlePercentageSelect(selectedPercentage);
    }
  }, [balance, selectedPercentage]);

  // Add an effect to refetch balance when token changes with MiniPay
  useEffect(() => {
    if (isMiniPay && selectedToken) {
      refetchBalance();
    }
  }, [isMiniPay, selectedToken, refetchBalance]);

  const handlePercentageSelect = (percentage: string) => {
    setSelectedPercentage(percentage);
    
    // Calculate amount based on the selected percentage of user's balance
    if (balance && balance !== "0.00") {
      const numericBalance = parseFloat(balance);
      const percentValue = parseInt(percentage.replace("%", ""));
      const calculatedAmount = (numericBalance * percentValue / 100).toFixed(2);
      setAmount(calculatedAmount);
    } else {
      setAmount("0.00");
    }
  };

  const handleAmountChange = (e: ChangeEvent<HTMLInputElement>) => {
    // Reset selected percentage when manually changing amount
    setSelectedPercentage(null);
    
    const value = e.target.value;
    // Allow only numbers and decimal point
    if (/^(\d*\.?\d*)$/.test(value) || value === '') {
      setAmount(value === '' ? '0.00' : value);
    }
  };

  const handleSelectedToken = (value: string) => {
    setSelectedToken(value);
    // Reset values
    setSelectedPercentage(null);
    setAmount("0.00");
    
    // Force refetch for MiniPay users
    if (isMiniPay) {
      setTimeout(() => {
        refetchBalance();
      }, 500);
    }
  };

  const navigateToBorrow = () => {
    router.push('/borrow');
  };
  
  const navigateToPositions = () => {
    router.push('/positions');
  };

  // Determine if amount exceeds balance
  const isAmountValid = () => {
    if (!balance || balance === "0.00") return false;
    if (!amount || amount === "0.00") return false;
    
    const numericAmount = parseFloat(amount);
    const numericBalance = parseFloat(balance);
    
    // Check if amount is at least 0.1 tokens (minimum required)
    const MIN_AMOUNT = 0.1;
    
    console.log('Validating amount:', {
      amount: numericAmount,
      balance: numericBalance,
      minAmount: MIN_AMOUNT,
      isValid: numericAmount >= MIN_AMOUNT && numericAmount <= numericBalance
    });
    
    return numericAmount >= MIN_AMOUNT && numericAmount <= numericBalance;
  };

  // Get the error message for invalid amount
  const getAmountErrorMessage = () => {
    if (!selectedToken || amount === "0.00") return null;
    
    const numericAmount = parseFloat(amount);
    const numericBalance = parseFloat(balance || "0");
    
    if (numericAmount < 0.1) {
      return `Minimum deposit is 0.1 ${selectedToken.toUpperCase()}`;
    }
    
    if (numericAmount > numericBalance) {
      return "Amount exceeds balance";
    }
    
    return null;
  };

  // Handle position creation
  const handleCreatePosition = async () => {
    if (!selectedToken || !isAmountValid() || !isConnected) return;
    
    try {
      console.log(`Starting supply position creation process for ${amount} ${selectedToken}`);
      console.log(`Token decimals: ${decimals}`);
      console.log(`Expected on-chain amount: ${parseFloat(amount) * Math.pow(10, decimals)}`);
      console.log(`User balance: ${balance} ${selectedToken}`);
      
      await createSupplyPosition(selectedToken, amount, decimals);
    } catch (err) {
      console.error("Failed to create supply position:", err);
    }
  };

  // Render transaction status alert
  const renderTransactionStatus = () => {
    console.log("Transaction status:", { isLoading, isSuccess, error, txHash, isApprovalStepComplete });
    
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
            {approvalTxHash && (
              <AlertDescription>
                <a 
                  href={`https://celoscan.io/tx/${approvalTxHash}`} 
                  target="_blank" 
                  rel="noopener noreferrer"
                  className="flex items-center text-green-600 hover:text-green-700 text-xs mt-1"
                >
                  <ExternalLink className="h-3 w-3 mr-1" />
                  View approval transaction
                </a>
              </AlertDescription>
            )}
          </Alert>
          
          {/* Supply step - only show if approval is complete */}
          {isApprovalStepComplete && (
            <Alert variant={isSuccess ? "success" : "default"} className={isSuccess ? "" : "animate-pulse"}>
              {isSuccess ? (
                <CheckCircle className="h-4 w-4 mr-2" />
              ) : (
                <Loader2 className="h-4 w-4 mr-2 animate-spin" />
              )}
              <AlertTitle>Step 2: {isSuccess ? "Supply complete" : "Supplying tokens..."}</AlertTitle>
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
        </div>
      );
    }
    
    if (isSuccess || txHash) {
      return (
        <Alert variant="success" className="mb-4">
          <CheckCircle className="h-4 w-4 mr-2" />
          <AlertTitle>Position created!</AlertTitle>
          <AlertDescription>
            Your deposit has been successfully added to Aave Celo Markets.
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
      <div className="container mx-auto px-4 py-8 flex-1 flex flex-col items-center justify-center">
        <div className="w-full max-w-md">
          <div className="mb-6">
            {renderTransactionStatus()}
            
            <Card className="bg-card p-6 rounded-2xl shadow-sm dark:shadow-none">
              <h3 className="text-xl font-medium mb-4">I will deposit</h3>
              
              {/* Amount input and token selection */}
              <div className="mb-4 p-4 bg-muted rounded-lg">
                <div className="flex justify-between items-center mb-2">
                  <Input 
                    type="text"
                    value={amount}
                    onChange={handleAmountChange}
                    className="text-3xl font-semibold border-none bg-transparent p-0 h-auto text-left w-[60%] focus-visible:ring-0 focus-visible:ring-offset-0"
                    placeholder="0.00"
                    disabled={isLoading || isSuccess}
                  />
                  <Select 
                    onValueChange={handleSelectedToken}
                    disabled={isLoading || isSuccess}
                  >
                    <SelectTrigger className="w-[180px] border-none bg-transparent">
                      <SelectValue placeholder="Choose Token" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="usdc">USDC</SelectItem>
                      <SelectItem value="usdt">USDT</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
                {isConnected && selectedToken ? (
                  <div>
                    <p className="text-muted-foreground">Balance: {balance} {selectedToken.toUpperCase()}</p>
                    {isMiniPay && (
                      <p className="text-xs text-green-600 dark:text-green-400 mt-1">
                        MiniPay wallet detected
                      </p>
                    )}
                  </div>
                ) : (
                  <p className="text-muted-foreground">select token</p>
                )}
                {getAmountErrorMessage() && (
                  <p className="text-red-500 text-sm mt-1">{getAmountErrorMessage()}</p>
                )}
              </div>
              
              {/* Percentage buttons */}
              <div className="grid grid-cols-2 gap-4 mb-6">
                <Button 
                  variant={selectedPercentage === "25%" ? "default" : "outline"}
                  className="rounded-lg" 
                  onClick={() => handlePercentageSelect("25%")}
                  disabled={!isConnected || !selectedToken || balance === "0.00" || isLoading || isSuccess}
                >
                  25%
                </Button>
                <Button 
                  variant={selectedPercentage === "50%" ? "default" : "outline"}
                  className="rounded-lg" 
                  onClick={() => handlePercentageSelect("50%")}
                  disabled={!isConnected || !selectedToken || balance === "0.00" || isLoading || isSuccess}
                >
                  50%
                </Button>
                <Button 
                  variant={selectedPercentage === "75%" ? "default" : "outline"}
                  className="rounded-lg" 
                  onClick={() => handlePercentageSelect("75%")}
                  disabled={!isConnected || !selectedToken || balance === "0.00" || isLoading || isSuccess}
                >
                  75%
                </Button>
                <Button 
                  variant={selectedPercentage === "100%" ? "default" : "outline"}
                  className="rounded-lg" 
                  onClick={() => handlePercentageSelect("100%")}
                  disabled={!isConnected || !selectedToken || balance === "0.00" || isLoading || isSuccess}
                >
                  100%
                </Button>
              </div>
              
              {/* Borrow and Multiply options */}
              <div className="flex mb-4 gap-4">
                <Button 
                  variant="outline" 
                  className="flex-1 flex items-center justify-center gap-2"
                  onClick={navigateToBorrow}
                  disabled={isLoading}
                >
                  <Plus className="h-4 w-4" />
                  Borrow
                </Button>
              </div>

              {/* Overview section toggle */}
              <button
                className="w-full border border-primary/50 rounded-lg py-2 text-primary flex items-center justify-center gap-2 mb-4 bg-transparent"
                onClick={() => setOverviewOpen((v) => !v)}
                disabled={isLoading}
              >
                Overview {overviewOpen ? <ChevronUp className="h-4 w-4" /> : <ChevronDown className="h-4 w-4" />}
              </button>
              
              {/* Overview section */}
              {overviewOpen && (
                <div className="mb-4">
                  <Card className="bg-card border p-4 rounded-lg">
                    <div className="border-b border-border pb-4 mb-4">
                      <h4 className="text-xl font-semibold mb-4">Pool</h4>
                      <div className="flex justify-between items-center">
                        <div>
                          <p className="text-muted-foreground mb-1">Asset</p>
                          <div className="flex items-center gap-2">
                            <TokenIcon symbol={selectedToken} />
                            <div>
                              <p className="font-semibold">{amount}</p>
                              <p className="text-muted-foreground">${amount}</p>
                            </div>
                          </div>
                        </div>
                        <div className="w-8 h-8 bg-gray-200 dark:bg-gray-700 rounded-full flex items-center justify-center">
                          <span className="text-gray-500 dark:text-gray-300">N</span>
                        </div>
                      </div>
                    </div>
                    
                    <div className="mb-4">
                      <div className="flex justify-between items-center mb-2">
                        <p className="text-muted-foreground">Supply APY</p>
                        <p className="font-semibold">
                          {currentApy !== null ? `${currentApy}%` : 'N/A'}
                        </p>
                      </div>
                      <div className="flex justify-between items-center">
                        <div className="flex items-center gap-1">
                          <p className="text-muted-foreground">Monthly yield</p>
                          <Info className="h-4 w-4 text-muted-foreground" />
                        </div>
                        <p className="font-semibold">
                          {selectedToken ? `${monthlyYield} ${selectedToken.toUpperCase()}` : 'N/A'}
                        </p>
                      </div>
                    </div>
                    
                    <div className="rounded-lg bg-blue-50 dark:bg-blue-950 p-3 mb-3 text-xs text-blue-600 dark:text-blue-400">
                      <p className="font-medium mb-1">Supply-Only Position:</p>
                      <p>Your deposit will be supplied to Aave on Celo, allowing you to earn interest on your assets.</p>
                      <p className="mt-1">You'll be able to withdraw your funds at any time from the Positions page.</p>
                    </div>
                  </Card>
                </div>
              )}
              
              <button
                className="w-full border border-primary/50 rounded-lg py-2 text-primary flex items-center justify-center gap-2 mb-4 bg-transparent"
                onClick={() => setDetailsOpen((v) => !v)}
                disabled={isLoading}
              >
                More details {detailsOpen ? <ChevronUp className="h-4 w-4" /> : <ChevronDown className="h-4 w-4" />}
              </button>
              
              {detailsOpen && (
                <div className="bg-muted rounded-lg p-4 mb-4">
                  <div className="flex justify-between text-muted-foreground mb-2">
                    <span>Market</span>
                    <span>Aave Celo Markets</span>
                    <span className="flex items-center gap-1">Market fee <Info className="h-4 w-4" /> <span>0%</span></span>
                  </div>
                  <div className="flex justify-between text-muted-foreground mb-2">
                    <span>Supplied asset</span>
                    <span>0 → {amount} {selectedToken?.toUpperCase() || ''}</span>
                  </div>
                  <div className="flex justify-between text-muted-foreground mb-2">
                    <span>Supply APY</span>
                    <span>{currentApy !== null ? `${currentApy}%` : 'N/A'}</span>
                  </div>
                  <div className="flex justify-between text-muted-foreground">
                    <span>Position type</span>
                    <span>Supply only (no borrowing)</span>
                  </div>
                </div>
              )}
              
              {isSuccess ? (
                <Button
                  className="w-full bg-green-600 hover:bg-green-700 text-white py-6 text-lg"
                  onClick={navigateToPositions}
                >
                  <ArrowRight className="h-5 w-5 mr-2" />
                  View Your Positions
                </Button>
              ) : (
                <Button 
                  className="w-full bg-primary hover:bg-primary/90 text-primary-foreground py-6 text-lg"
                  disabled={!isConnected || !selectedToken || !isAmountValid() || isLoading || isSuccess}
                  onClick={handleCreatePosition}
                >
                  {isLoading ? (
                    <>
                      <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                      Creating Position...
                    </>
                  ) : (
                    "Start earning"
                  )}
              </Button>
              )}
            </Card>
          </div>
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