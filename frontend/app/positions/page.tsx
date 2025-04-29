"use client";

import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/components/ui/tabs";
import { Info } from "lucide-react";

export default function Positions() {
  return (
    <main className="min-h-screen bg-background text-foreground flex flex-col justify-between">
      <div className="container mx-auto px-4 py-8 flex-1 flex flex-col items-center">
        <div className="w-full max-w-xl">
          <h1 className="text-4xl font-bold mb-4" style={{ fontFamily: 'inherit', letterSpacing: '-1px' }}>Positions</h1>
          <div className="flex justify-between text-muted-foreground mb-6">
            <div className="flex flex-col items-center flex-1">
              <span className="text-sm">Total supplied</span>
              <span className="text-2xl font-bold text-foreground">$0.99</span>
            </div>
            <div className="flex flex-col items-center flex-1">
              <span className="text-sm">Total collateral</span>
              <span className="text-2xl font-bold text-foreground">$0</span>
            </div>
            <div className="flex flex-col items-center flex-1">
              <span className="text-sm">Total borrowed</span>
              <span className="text-2xl font-bold text-foreground">$0</span>
            </div>
          </div>
          {/* DeFi Spring Rewards */}
          <div className="mb-6">
            <h2 className="text-2xl font-bold mb-2" style={{ fontFamily: 'inherit', letterSpacing: '-1px' }}>DeFi Spring Rewards</h2>
            <Card className="bg-card p-4 rounded-2xl">
              <div className="flex flex-col sm:flex-row justify-between items-center gap-4">
                <div className="flex flex-col items-center flex-1">
                  <span className="text-sm text-muted-foreground">Earned this week</span>
                  <span className="text-lg font-bold text-foreground">0 STRK</span>
                </div>
                <div className="flex flex-col items-center flex-1">
                  <span className="text-sm text-muted-foreground">Available to claim</span>
                  <span className="text-lg font-bold text-foreground">0 STRK</span>
                </div>
                <div className="flex flex-col items-center flex-1">
                  <span className="text-sm text-muted-foreground">Next claim</span>
                  <span className="text-lg font-bold text-foreground">3D</span>
                  <Button className="mt-2 bg-primary text-primary-foreground px-6">Claim</Button>
                </div>
              </div>
            </Card>
          </div>
          {/* Tabs for Earning/Borrowing/Multiply */}
          <Tabs defaultValue="earning" className="w-full">
            <TabsList className="flex gap-4 bg-transparent p-0 mb-2 border-b border-border">
              <TabsTrigger value="earning" className="text-2xl font-bold px-0 py-2 mr-6 border-b-2 border-transparent data-[state=active]:border-foreground data-[state=active]:text-foreground" style={{ fontFamily: 'inherit', letterSpacing: '-1px' }}>Earning</TabsTrigger>
              <TabsTrigger value="borrowing" className="text-2xl font-bold px-0 py-2 mr-6 border-b-2 border-transparent data-[state=active]:border-foreground data-[state=active]:text-foreground" style={{ fontFamily: 'inherit', letterSpacing: '-1px' }}>Borrowing</TabsTrigger>
              <TabsTrigger value="multiply" className="text-2xl font-bold px-0 py-2 border-b-2 border-transparent data-[state=active]:border-foreground data-[state=active]:text-foreground" style={{ fontFamily: 'inherit', letterSpacing: '-1px' }}>Multiply</TabsTrigger>
            </TabsList>
            <TabsContent value="earning">
              <Card className="bg-card p-6 rounded-2xl">
                <span className="block text-xl mb-2">Genesis Pool</span>
                <span className="block text-muted-foreground">USD Coin</span>
                <div className="flex items-center gap-2 mt-2 mb-4">
                  <img src="https://cryptologos.cc/logos/usd-coin-usdc-logo.png" alt="USDC" className="h-8 w-8" />
                  <span className="text-2xl font-bold">0.999999</span>
                  <span className="text-muted-foreground">$0.99</span>
                </div>
                <div className="mb-4">
                  <div className="flex items-center gap-2 mb-2">
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
                <div className="flex gap-4 mt-2">
                  <Button variant="secondary" className="flex-1 bg-card border border-border text-foreground">Modify</Button>
                  <Button variant="secondary" className="flex-1 bg-card border border-border text-foreground">Close</Button>
                </div>
              </Card>
            </TabsContent>
            <TabsContent value="borrowing">
              <Card className="bg-card p-6 rounded-2xl text-center text-muted-foreground">No borrowing positions</Card>
            </TabsContent>
            <TabsContent value="multiply">
              <Card className="bg-card p-6 rounded-2xl text-center text-muted-foreground">No multiply positions</Card>
            </TabsContent>
          </Tabs>
        </div>
      </div>
    </main>
  );
}