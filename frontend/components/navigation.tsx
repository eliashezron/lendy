"use client";

import Link from "next/link";
import { useRouter, usePathname } from "next/navigation";
import { cn } from "@/lib/utils";
import { Sun, Moon } from "lucide-react";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { useEffect, useState } from "react";
import { ConnectWallet } from "@/components/connect-wallet";

export function Navigation() {
  const router = useRouter();
  const pathname = usePathname();
  const [theme, setTheme] = useState('dark');

  useEffect(() => {
    if (typeof window !== 'undefined') {
      const saved = localStorage.getItem('theme');
      if (saved) {
        setTheme(saved);
      } else {
        // Use system preference if no theme is saved
        const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
        setTheme(prefersDark ? 'dark' : 'light');
      }
    }
  }, []);

  useEffect(() => {
    if (typeof window !== 'undefined') {
      document.documentElement.classList.remove('light', 'dark');
      document.documentElement.classList.add(theme);
      localStorage.setItem('theme', theme);
    }
  }, [theme]);

  const pages = [
    { value: "/", label: "Home" },
    { value: "/earn", label: "Earn" },
    { value: "/borrow", label: "Borrow" },
    { value: "/positions", label: "Positions" },
  ];

  return (
    <header className="border-b">
      <div className="container mx-auto px-4">
        <div className="flex h-14 sm:h-16 items-center justify-between">
          <div className="flex items-center gap-1 sm:gap-2">
            <Link href="/" className="text-xl sm:text-2xl font-bold">LENDY</Link>
            <Select value={pathname} onValueChange={v => router.push(v)}>
              <SelectTrigger className="w-[100px] sm:w-[120px] border-none bg-transparent text-sm sm:text-base">
                <SelectValue />
              </SelectTrigger>
              <SelectContent >
                {pages.map((page) => (
                  <SelectItem key={page.value} value={page.value} >
                    {page.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          <div className="flex items-center gap-2">
            <button
              aria-label="Toggle theme"
              className="rounded-lg p-2 border border-gray-700 bg-transparent hover:bg-gray-800"
              onClick={() => setTheme(theme === 'dark' ? 'light' : 'dark')}
            >
              {theme === 'dark' ? <Sun className="h-5 w-5" /> : <Moon className="h-5 w-5" />}
            </button>
            <ConnectWallet />
          </div>
        </div>
      </div>
    </header>
  );
}