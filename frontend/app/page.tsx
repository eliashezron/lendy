"use client";

import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { ArrowRight, Sun } from "lucide-react";
import Link from "next/link";
import { useState } from "react";

export default function Home() {
  const options = [
    { value: "earn", label: "Earn" },
    { value: "borrow", label: "Borrow" },
    { value: "positions", label: "Positions" },
  ];
  const [selected, setSelected] = useState("earn");

  return (
    <main className="flex min-h-screen flex-col bg-background text-foreground">
      <div className="container mx-auto flex flex-1 flex-col items-center justify-center p-4 sm:px-4">
        <div className="w-full max-w-xl">
          <div className="flex items-center gap-2 rounded-xl bg-card p-3 sm:p-4">
            <span className="text-sm sm:text-base text-muted-foreground">I want to</span>
            <Select defaultValue="earn" onValueChange={setSelected}>
              <SelectTrigger className="flex-1 border-none bg-transparent text-foreground text-sm sm:text-base min-w-[100px]">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {options.map((option) => (
                  <SelectItem key={option.value} value={option.value}>
                    {option.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
            <Link href={`/${selected}`}>
              <button className="rounded-lg bg-primary p-2 sm:p-3 hover:bg-primary/80 text-primary-foreground">
                <ArrowRight className="h-4 w-4 sm:h-5 sm:w-5" />
              </button>
            </Link>
          </div>
        </div>
      </div>

      <div className="container mx-auto px-4 py-6 sm:py-8">
        <div className="text-center">
          <p className="mb-4 text-sm sm:text-base text-muted-foreground px-4">
            Lendy is a fully open, transparent and secure crypto lending protocol built on Celo.
          </p>
          <div className="flex flex-wrap justify-center gap-3 sm:gap-4 text-sm sm:text-base">
            <Link href="#" className="text-blue-500 hover:text-blue-400">Help</Link>
            <Link href="#" className="text-blue-500 hover:text-blue-400">Docs</Link>
            <Link href="#" className="text-blue-500 hover:text-blue-400">About</Link>
            <Link href="#" className="text-blue-500 hover:text-blue-400">Terms</Link>
            <Link href="#" className="text-blue-500 hover:text-blue-400">Privacy</Link>
            <Link href="#" className="text-blue-500 hover:text-blue-400">Brand</Link>
          </div>
        </div>
      </div>
    </main>
  );
}