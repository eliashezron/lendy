"use client";

import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { useState, useEffect, ChangeEvent, useMemo } from "react";
import { Info, ChevronDown, ChevronUp, Plus, Loader2, CheckCircle, AlertCircle } from "lucide-react";
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
import { useCreatePosition } from "@/hooks/useCreatePosition";
import { Alert, AlertTitle, AlertDescription } from "@/components/ui/alert";

// Supply APY rates from Aave
const SUPPLY_APY_RATES = {
  usdc: 0.1, // 0.1%
  usdt: 0.01, // 0.01%
};

export default function Earn() {
  const [detailsOpen, setDetailsOpen] = useState(false);
  const [amount, setAmount] = useState("0.00");
  const [selectedPercentage, setSelectedPercentage] = useState<string | null>(null);
  const [selectedToken, setSelectedToken] = useState<string | null>(null);
  const { balance, rawBalance, decimals } = useTokenBalance(selectedToken);
  const { isConnected } = useAccount();
  const router = useRouter();
  const { createPosition, isLoading, isSuccess, error, txHash } = useCreatePosition();

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

  const navigateToBorrow = () => {
    router.push('/borrow');
  };

  // Determine if amount exceeds balance
  const isAmountValid = () => {
    if (!balance || balance === "0.00") return false;
    if (!amount || amount === "0.00") return false;
    
    const numericAmount = parseFloat(amount);
    const numericBalance = parseFloat(balance);
    
    return numericAmount > 0 && numericAmount <= numericBalance;
  };

  // Handle position creation
  const handleCreatePosition = async () => {
    if (!selectedToken || !isAmountValid() || !isConnected) return;
    
    try {
      await createPosition(selectedToken, amount, decimals);
    } catch (err) {
      console.error("Failed to create position:", err);
    }
  };

  // Render transaction status alert
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
    
    if (isSuccess) {
      return (
        <Alert variant="success" className="mb-4">
          <CheckCircle className="h-4 w-4 mr-2" />
          <AlertTitle>Position created!</AlertTitle>
          <AlertDescription>
            Your deposit has been successfully added to Aave Celo Markets.
            {txHash && (
              <a 
                href={`https://celoscan.io/tx/${txHash}`} 
                target="_blank" 
                rel="noopener noreferrer"
                className="block mt-2 underline"
              >
                View transaction
              </a>
            )}
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
                  />
                  <Select onValueChange={(value) => setSelectedToken(value)}>
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
                  <p className="text-muted-foreground">Balance: {balance} {selectedToken.toUpperCase()}</p>
                ) : (
                  <p className="text-muted-foreground">select token</p>
                )}
                {isConnected && selectedToken && parseFloat(amount) > parseFloat(balance) && (
                  <p className="text-red-500 text-sm mt-1">Amount exceeds balance</p>
                )}
              </div>
              
              {/* Percentage buttons */}
              <div className="grid grid-cols-2 gap-4 mb-6">
                <Button 
                  variant={selectedPercentage === "25%" ? "default" : "outline"}
                  className="rounded-lg" 
                  onClick={() => handlePercentageSelect("25%")}
                  disabled={!isConnected || !selectedToken || balance === "0.00" || isLoading}
                >
                  25%
                </Button>
                <Button 
                  variant={selectedPercentage === "50%" ? "default" : "outline"}
                  className="rounded-lg" 
                  onClick={() => handlePercentageSelect("50%")}
                  disabled={!isConnected || !selectedToken || balance === "0.00" || isLoading}
                >
                  50%
                </Button>
                <Button 
                  variant={selectedPercentage === "75%" ? "default" : "outline"}
                  className="rounded-lg" 
                  onClick={() => handlePercentageSelect("75%")}
                  disabled={!isConnected || !selectedToken || balance === "0.00" || isLoading}
                >
                  75%
                </Button>
                <Button 
                  variant={selectedPercentage === "100%" ? "default" : "outline"}
                  className="rounded-lg" 
                  onClick={() => handlePercentageSelect("100%")}
                  disabled={!isConnected || !selectedToken || balance === "0.00" || isLoading}
                >
                  100%
                </Button>
              </div>
              
              {/* Borrow and Multiply options */}
              <div className="flex mb-8 gap-4">
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
              {/* Overview section */}
              <div className="mb-4">
                <h3 className="text-lg text-muted-foreground mb-4">Overview</h3>
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
                </Card>
              </div>
              
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
                  <div className="flex justify-between text-muted-foreground">
                    <span>Supply APY</span>
                    <span>{currentApy !== null ? `${currentApy}%` : 'N/A'}</span>
                  </div>
                </div>
              )}
              
              <Button 
                className="w-full bg-primary hover:bg-primary/90 text-primary-foreground py-6 text-lg"
                disabled={!isConnected || !selectedToken || !isAmountValid() || isLoading}
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