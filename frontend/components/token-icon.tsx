import React from 'react';

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

  const symbolToIcon: Record<string, { label: string, bgColor: string, textColor: string }> = {
    celo: { label: 'C', bgColor: 'bg-[#FBCC5C]', textColor: 'text-black' },
    usdc: { label: 'U', bgColor: 'bg-[#2775CA]', textColor: 'text-white' },
    usdt: { label: '$', bgColor: 'bg-[#25D366]', textColor: 'text-white' },
    ceur: { label: '€', bgColor: 'bg-[#35A8E0]', textColor: 'text-white' },
  };

  // Default for unknown or null symbols
  const iconData = symbol && symbolToIcon[symbol.toLowerCase()] 
    ? symbolToIcon[symbol.toLowerCase()] 
    : { label: '?', bgColor: 'bg-gray-300 dark:bg-gray-700', textColor: 'text-gray-700 dark:text-gray-300' };

  return (
    <div className={`${sizeClasses[size]} ${iconData.bgColor} rounded-full flex items-center justify-center ${iconData.textColor} font-semibold`}>
      {iconData.label}
    </div>
  );
} 