"use client";

import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Button } from "@/components/ui/button";

const markets = [
  {
    asset: "ETH",
    apy: "3.50%",
    totalSupplied: "$125.5M",
    walletBalance: "0.00",
  },
  {
    asset: "USDC",
    apy: "5.20%",
    totalSupplied: "$89.2M",
    walletBalance: "0.00",
  },
  {
    asset: "USDT",
    apy: "4.80%",
    totalSupplied: "$67.8M",
    walletBalance: "0.00",
  },
];

export function LendingMarkets() {
  return (
    <div className="rounded-lg border bg-card">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Asset</TableHead>
            <TableHead>APY</TableHead>
            <TableHead>Total Supplied</TableHead>
            <TableHead>Wallet Balance</TableHead>
            <TableHead></TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {markets.map((market) => (
            <TableRow key={market.asset}>
              <TableCell className="font-medium">{market.asset}</TableCell>
              <TableCell>{market.apy}</TableCell>
              <TableCell>{market.totalSupplied}</TableCell>
              <TableCell>{market.walletBalance}</TableCell>
              <TableCell>
                <Button variant="outline" size="sm">
                  Supply
                </Button>
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  );
}