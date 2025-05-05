import React from 'react';
import Image from 'next/image';
import usdcLogo from '@/public/data/USDC.svg';
import usdtLogo from '@/public/data/USDT.svg';

type TokenIconProps = {
  symbol: string | null;
  size?: 'sm' | 'md' | 'lg';
};

export function TokenIcon({ symbol, size = 'md' }: TokenIconProps) {
  const sizeClasses = {
    sm: 'w-6 h-6',
    md: 'w-8 h-8',
    lg: 'w-10 h-10',
  };

  const sizePixels = {
    sm: 24,
    md: 32,
    lg: 40,
  };

  if (!symbol) {
    // Default for null or undefined symbols
    return (
      <div className={`${sizeClasses[size]} bg-gray-300 dark:bg-gray-700 rounded-full flex items-center justify-center text-gray-700 dark:text-gray-300 font-semibold`}>
        ?
      </div>
    );
  }

  const lowerSymbol = symbol.toLowerCase();

  // Handle USDC and USDT with imported SVG files
  if (lowerSymbol === 'usdc' || lowerSymbol === 'usdt') {
    const logoSrc = lowerSymbol === 'usdc' ? usdcLogo : usdtLogo;
    
    return (
      <div className={`${sizeClasses[size]} relative`}>
        <Image
          src={logoSrc}
          alt={`${symbol.toUpperCase()} logo`}
          width={sizePixels[size]}
          height={sizePixels[size]}
          className="rounded-full"
        />
      </div>
    );
  }

  // For other tokens, use the letter approach
  const symbolToIcon: Record<string, { label: string, bgColor: string, textColor: string }> = {
    celo: { label: 'C', bgColor: 'bg-[#FBCC5C]', textColor: 'text-black' },
    ceur: { label: '€', bgColor: 'bg-[#35A8E0]', textColor: 'text-white' },
  };

  // Fallback for unknown symbols
  const iconData = symbolToIcon[lowerSymbol] || 
    { label: symbol[0].toUpperCase(), bgColor: 'bg-gray-300 dark:bg-gray-700', textColor: 'text-gray-700 dark:text-gray-300' };

  return (
    <div className={`${sizeClasses[size]} ${iconData.bgColor} rounded-full flex items-center justify-center ${iconData.textColor} font-semibold`}>
      {iconData.label}
    </div>
  );
} 