"use client";

import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { useState } from "react";
import { Info, ChevronDown, ChevronUp } from "lucide-react";

export default function Earn() {
  const [detailsOpen, setDetailsOpen] = useState(true);

  return (
    <main className="min-h-screen bg-background text-foreground flex flex-col justify-between">
      <div className="container mx-auto px-4 py-8 flex-1 flex flex-col items-center justify-center">
        <div className="w-full max-w-md">
          <div className="mb-6">
            <span className="block text-lg text-muted-foreground mb-2">Overview</span>
            <Card className="bg-card p-6 rounded-2xl">
              <div className="mb-4">
                <span className="block text-2xl font-semibold mb-1">Genesis Pool</span>
                <span className="block text-muted-foreground">USD Coin</span>
                <div className="flex items-center gap-2 mt-2">
                  <img src="https://cryptologos.cc/logos/usd-coin-usdc-logo.png" alt="USDC" className="h-8 w-8" />
                  <span className="text-2xl font-bold">1</span>
                  <span className="text-muted-foreground">$0.99</span>
                </div>
              </div>
              <div className="flex flex-col gap-2 mb-4">
                <div className="flex items-center gap-2">
                  <span className="text-muted-foreground">Supply APY</span>
                  <span className="text-lg font-semibold">4.675%</span>
                  <span className="text-blue-400">✦</span>
                </div>
                <div className="flex items-center gap-2">
                  <span className="text-muted-foreground">Monthly yield</span>
                  <Info className="h-4 w-4 text-muted-foreground" />
                  <span className="text-lg font-semibold">&lt;$0.01</span>
                  <span className="text-blue-400">✦</span>
                </div>
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
                    <span>Genesis</span>
                    <span className="flex items-center gap-1">Market fee <Info className="h-4 w-4" /> <span>0%</span></span>
                  </div>
                  <div className="flex justify-between text-muted-foreground mb-2">
                    <span>Supplied asset</span>
                    <span>0 &rarr; 1 USDC</span>
                  </div>
                  <div className="flex justify-between text-muted-foreground">
                    <span>Supply APY</span>
                    <span>0.123% &rarr; 0.123%</span>
                  </div>
                </div>
              )}
              <div className="flex gap-4 mt-2">
                <Button variant="secondary" className="flex-1 bg-card border border-border text-foreground">Modify</Button>
                <Button className="flex-1 bg-primary hover:bg-primary/80 text-primary-foreground">Start earning</Button>
              </div>
            </Card>
          </div>
        </div>
      </div>
      <div className="container mx-auto px-4 pb-6">
        <div className="text-center">
          <p className="mb-4 text-sm sm:text-base text-muted-foreground px-4">
            Vesu is a fully open, transparent and secure crypto lending protocol built on Starknet.
          </p>
        </div>
      </div>
    </main>
  );
}