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
    apy: "4.20%",
    totalBorrowed: "$82.3M",
    available: "$43.2M",
  },
  {
    asset: "USDC",
    apy: "6.50%",
    totalBorrowed: "$45.6M",
    available: "$43.6M",
  },
  {
    asset: "USDT",
    apy: "5.90%",
    totalBorrowed: "$34.2M",
    available: "$33.6M",
  },
];

export function BorrowMarkets() {
  return (
    <div className="rounded-lg border bg-card">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Asset</TableHead>
            <TableHead>APY</TableHead>
            <TableHead>Total Borrowed</TableHead>
            <TableHead>Available</TableHead>
            <TableHead></TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {markets.map((market) => (
            <TableRow key={market.asset}>
              <TableCell className="font-medium">{market.asset}</TableCell>
              <TableCell>{market.apy}</TableCell>
              <TableCell>{market.totalBorrowed}</TableCell>
              <TableCell>{market.available}</TableCell>
              <TableCell>
                <Button variant="outline" size="sm">
                  Borrow
                </Button>
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  );
}