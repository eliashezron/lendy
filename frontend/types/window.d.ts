declare interface Window {
  ethereum?: {
    isMetaMask?: boolean;
    isMiniPay?: boolean;
    on?: (...args: any[]) => void;
    removeListener?: (...args: any[]) => void;
    autoRefreshOnNetworkChange?: boolean;
    request?: (...args: any[]) => Promise<any>;
  };
} 