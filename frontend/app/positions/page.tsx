"use client";

import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/components/ui/tabs";
import { Info, Loader2, ExternalLink } from "lucide-react";
import { useUserPositions } from "@/hooks/useUserPositions";
import { useAccount } from "wagmi";
import { useState } from "react";

export default function Positions() {
  const { isConnected, address } = useAccount();
  const { positions, isLoading, error, totalSupplied, totalCollateral, totalBorrowed } = useUserPositions();
  const [currentTab, setCurrentTab] = useState<string>("earning");

  // Filter positions based on the current tab
  const filteredPositions = positions.filter(position => {
    if (currentTab === "earning" && position.borrowAmount === BigInt(0)) {
      return true; // Only supply positions
    }
    if (currentTab === "borrowing" && position.borrowAmount > BigInt(0)) {
      return true; // Only borrow positions
    }
    return false;
  });

  const handleTabChange = (value: string) => {
    setCurrentTab(value);
  };

  const renderCurrency = (amount: string) => {
    return `$${amount}`;
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
                  <span className="block text-muted-foreground">{position.assetSymbol}</span>
                  <div className="flex items-center gap-2 mt-2 mb-4">
                    <div className="h-8 w-8 bg-blue-100 dark:bg-blue-900 rounded-full flex items-center justify-center text-blue-500 font-bold">
                      {position.assetSymbol?.[0]}
                    </div>
                    <span className="text-2xl font-bold">{position.formattedCollateralAmount}</span>
                    <span className="text-muted-foreground">${position.formattedCollateralAmount}</span>
                  </div>
                  <div className="mb-4">
                    <div className="flex items-center gap-2 mb-2">
                      <span className="text-muted-foreground">Supply APY</span>
                      <span className="text-lg font-semibold">
                        {position.assetSymbol === 'USDC' ? '0.1%' : '0.01%'}
                      </span>
                      <span className="text-blue-400">✦</span>
                    </div>
                    <div className="flex items-center gap-2">
                      <span className="text-muted-foreground">Monthly yield</span>
                      <Info className="h-4 w-4 text-muted-foreground" />
                      <span className="text-lg font-semibold">
                        {(parseFloat(position.formattedCollateralAmount || '0') * 
                          (position.assetSymbol === 'USDC' ? 0.1 : 0.01) / 100 / 12).toFixed(6)}
                      </span>
                      <span className="text-blue-400">✦</span>
                    </div>
                  </div>
                  <div className="flex gap-4 mt-2">
                    <Button variant="secondary" className="flex-1 bg-card border border-border text-foreground">Modify</Button>
                    <Button variant="secondary" className="flex-1 bg-card border border-border text-foreground">Close</Button>
                  </div>
                </Card>
              ))}
            </TabsContent>
            
            <TabsContent value="borrowing">
              {isConnected && !isLoading && !error && filteredPositions.length > 0 && filteredPositions.map((position) => (
                <Card key={position.positionId} className="bg-card p-6 rounded-2xl mb-4">
                  <span className="block text-xl mb-2">Aave Celo Pool</span>
                  <span className="block text-muted-foreground">{position.assetSymbol}</span>
                  <div className="flex items-center gap-2 mt-2 mb-4">
                    <div className="h-8 w-8 bg-blue-100 dark:bg-blue-900 rounded-full flex items-center justify-center text-blue-500 font-bold">
                      {position.assetSymbol?.[0]}
                    </div>
                    <span className="text-2xl font-bold">{position.formattedBorrowAmount}</span>
                    <span className="text-muted-foreground">${position.formattedBorrowAmount}</span>
                  </div>
                  <div className="mb-4">
                    <div className="flex items-center gap-2 mb-2">
                      <span className="text-muted-foreground">Borrow APY</span>
                      <span className="text-lg font-semibold">
                        {position.assetSymbol === 'USDC' ? '3.5%' : '3.2%'}
                      </span>
                    </div>
                    <div className="flex items-center gap-2">
                      <span className="text-muted-foreground">Collateral</span>
                      <span className="text-lg font-semibold">{position.formattedCollateralAmount} {position.assetSymbol}</span>
                    </div>
                  </div>
                  <div className="flex gap-4 mt-2">
                    <Button variant="secondary" className="flex-1 bg-card border border-border text-foreground">Repay</Button>
                    <Button variant="secondary" className="flex-1 bg-card border border-border text-foreground">More</Button>
                  </div>
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
    </main>
  );
}