"use client";

import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Select, SelectTrigger, SelectValue, SelectContent, SelectItem } from "@/components/ui/select";
import { Input } from "@/components/ui/input";
import { Info, ChevronDown, ChevronUp } from "lucide-react";
import { useState } from "react";

export default function Borrow() {
  const [detailsOpen, setDetailsOpen] = useState(true);
  const [depositMarket, setDepositMarket] = useState("");
  const [borrowMarket, setBorrowMarket] = useState("");

  return (
    <main className="min-h-screen bg-background text-foreground flex flex-col justify-between">
      <div className="container mx-auto px-2 py-6 flex-1 flex flex-col items-center justify-center">
        <div className="w-full max-w-md flex flex-col gap-6">
          {/* Deposit Card */}
          <Card className="bg-card p-4 rounded-2xl mb-2">
            <span className="block text-muted-foreground mb-2">I will deposit</span>
            <div className="bg-muted rounded-xl p-4 flex flex-col gap-2">
              <div className="flex items-center justify-between mb-2">
                <span className="text-3xl font-semibold text-foreground">0.00</span>
                <Select value={depositMarket} onValueChange={setDepositMarket}>
                  <SelectTrigger className="w-40 bg-muted text-foreground border-none focus:ring-0">
                    <SelectValue placeholder="Choose market" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="usdc">USDC</SelectItem>
                    <SelectItem value="eth">ETH</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <span className="text-muted-foreground text-sm mb-2">No USD price available</span>
              <div className="grid grid-cols-2 gap-2 mt-2">
                <Button variant="secondary" className="w-full bg-card border border-border text-foreground">25%</Button>
                <Button variant="secondary" className="w-full bg-card border border-border text-foreground">50%</Button>
                <Button variant="secondary" className="w-full bg-card border border-border text-foreground">75%</Button>
                <Button variant="secondary" className="w-full bg-card border border-border text-foreground">100%</Button>
              </div>
            </div>
          </Card>

          {/* Borrow Card */}
          <Card className="bg-card p-4 rounded-2xl mb-2">
            <span className="block text-muted-foreground mb-2">To borrow</span>
            <div className="bg-muted rounded-xl p-4 flex flex-col gap-2">
              <div className="flex items-center justify-between mb-2">
                <span className="text-3xl font-semibold text-foreground">0.00</span>
                <Select value={borrowMarket} onValueChange={setBorrowMarket}>
                  <SelectTrigger className="w-40 bg-muted text-foreground border-none focus:ring-0">
                    <SelectValue placeholder="Choose market" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="usdc">USDC</SelectItem>
                    <SelectItem value="eth">ETH</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <span className="text-muted-foreground text-sm mb-2">No USD price available</span>
              <div className="w-full h-1 bg-border rounded-full my-2" />
              <div className="grid grid-cols-2 gap-2 mt-2">
                <Button variant="secondary" className="w-full bg-card border border-border text-foreground">25%</Button>
                <Button variant="secondary" className="w-full bg-card border border-border text-foreground">50%</Button>
                <Button variant="secondary" className="w-full bg-card border border-border text-foreground">75%</Button>
                <Button variant="secondary" className="w-full bg-card border border-border text-foreground">95%</Button>
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
                        <span className="bg-border rounded-full h-8 w-8 flex items-center justify-center"> <span className="text-2xl">🪙</span> </span>
                        <span className="text-xl font-bold">0</span>
                        <span className="text-muted-foreground text-xs">$0.00</span>
                      </div>
                    </div>
                    <div>
                      <span className="block font-semibold">Collateral</span>
                      <div className="flex items-center gap-2 mt-1">
                        <span className="bg-border rounded-full h-8 w-8 flex items-center justify-center"> <span className="text-2xl">🪙</span> </span>
                        <span className="text-xl font-bold">0</span>
                        <span className="text-muted-foreground text-xs">$0.00</span>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
              <div className="flex flex-col md:flex-row gap-4 mb-4">
                <div className="flex-1">
                  <div className="flex justify-between text-muted-foreground">
                    <span>Borrow APR <Info className="inline h-4 w-4 ml-1" /></span>
                    <span>0%</span>
                  </div>
                  <div className="flex justify-between text-muted-foreground mt-2">
                    <span>Monthly cost</span>
                    <span>N/A</span>
                  </div>
                  <div className="flex justify-between text-muted-foreground mt-2">
                    <span>Liquidation price</span>
                    <span>N/A</span>
                  </div>
                </div>
                <div className="flex-1">
                  <div className="flex justify-between text-muted-foreground">
                    <span>Supply APY</span>
                    <span>N/A</span>
                  </div>
                  <div className="flex justify-between text-muted-foreground mt-2">
                    <span>Monthly yield <Info className="inline h-4 w-4 ml-1" /></span>
                    <span>N/A</span>
                  </div>
                  <div className="flex justify-between text-muted-foreground mt-2">
                    <span>Liquidation price</span>
                    <span>N/A</span>
                  </div>
                </div>
              </div>
              <div className="flex flex-col gap-2 mb-2">
                <span className="text-muted-foreground">Loan-to-value</span>
                <span className="text-2xl font-bold">N/A</span>
              </div>
              <button
                className="w-full border border-yellow-400 rounded-lg py-2 text-yellow-400 flex items-center justify-center gap-2 mb-4 bg-transparent"
                onClick={() => setDetailsOpen((v) => !v)}
              >
                More details {detailsOpen ? <ChevronUp className="h-4 w-4" /> : <ChevronDown className="h-4 w-4" />}
              </button>
              {detailsOpen && (
                <div className="bg-muted rounded-lg p-4 mb-4">
                  <div className="flex justify-between text-muted-foreground mb-2">
                    <span>Market</span>
                    <span>Not selected</span>
                    <span className="flex items-center gap-1">Market fee <Info className="h-4 w-4" /> <span>0%</span></span>
                  </div>
                  <div className="flex justify-between text-muted-foreground mb-2">
                    <span>LTV</span>
                    <span>0% &rarr; 0%</span>
                  </div>
                  <div className="flex justify-between text-muted-foreground mb-2">
                    <span>Supplied asset</span>
                    <span>0 &rarr; 0</span>
                  </div>
                  <div className="flex justify-between text-muted-foreground mb-2">
                    <span>Debt</span>
                    <span>0 &rarr; 0</span>
                  </div>
                  <div className="flex justify-between text-muted-foreground mb-2">
                    <span>Supply APY</span>
                    <span>0% &rarr; 0%</span>
                  </div>
                  <div className="flex justify-between text-muted-foreground">
                    <span>Borrow APR</span>
                    <span>0% &rarr; 0%</span>
                  </div>
                </div>
              )}
            </div>
          </Card>

          <Button className="w-full bg-card text-foreground text-lg py-4 mt-2 border border-border">Borrow</Button>
        </div>
      </div>
      <div className="container mx-auto px-4 pb-6">
        <div className="text-center">
          <p className="mb-4 text-sm sm:text-base text-muted-foreground px-4">
            Vesu is a fully open, transparent and secure crypto lending protocol built on Starknet.
          </p>
          <div className="flex flex-wrap justify-center gap-3 sm:gap-4 text-sm sm:text-base mt-2">
            <a href="#" className="text-blue-500 hover:text-blue-400">Help</a>
            <a href="#" className="text-blue-500 hover:text-blue-400">Docs</a>
            <a href="#" className="text-blue-500 hover:text-blue-400">About</a>
            <a href="#" className="text-blue-500 hover:text-blue-400">Terms</a>
            <a href="#" className="text-blue-500 hover:text-blue-400">Privacy</a>
            <a href="#" className="text-blue-500 hover:text-blue-400">Brand</a>
          </div>
        </div>
      </div>
    </main>
  );
}