"use client"

import { useEffect, useState } from "react"
import { Wallet } from "lucide-react"
import { useConnect, useAccount, useDisconnect } from "wagmi"
import { injected } from "wagmi/connectors"
import { Button } from "@/components/ui/button"

export function ConnectWallet() {
  const [hideConnectBtn, setHideConnectBtn] = useState(false)
  const [mounted, setMounted] = useState(false)
  const { connect } = useConnect()
  const { isConnected, address } = useAccount()
  const { disconnect } = useDisconnect()

  // Set mounted to true once the component is mounted
  useEffect(() => {
    setMounted(true)
  }, [])

  useEffect(() => {
    // Check if window is defined (browser environment)
    if (typeof window !== "undefined") {
      // Check if ethereum object exists and has isMiniPay property
      if (window.ethereum && window.ethereum.isMiniPay) {
        // User is using MiniPay so hide connect wallet button
        setHideConnectBtn(true)
        
        try {
          connect({ connector: injected({ target: "metaMask" }) })
        } catch (error) {
          console.error("Error connecting with MiniPay:", error)
        }
      }
    }
  }, [connect])

  // Render a placeholder with the same structure during SSR
  if (!mounted) {
    return (
      <Button className="flex items-center gap-1 sm:gap-2">
        <Wallet className="h-4 w-4 sm:h-5 sm:w-5" />
        <span className="hidden xs:inline">Connect Wallet</span>
      </Button>
    )
  }

  if (hideConnectBtn) {
    return null
  }

  if (isConnected && address) {
    return (
      <Button 
        variant="outline" 
        className="flex items-center gap-1 sm:gap-2" 
        onClick={() => disconnect()}
      >
        <Wallet className="h-4 w-4 sm:h-5 sm:w-5" />
        <span className="hidden xs:inline">
          {`${address.slice(0, 6)}...${address.slice(-4)}`}
        </span>
      </Button>
    )
  }

  return (
    <Button 
      className="flex items-center gap-1 sm:gap-2" 
      onClick={() => connect({ connector: injected() })}
    >
      <Wallet className="h-4 w-4 sm:h-5 sm:w-5" />
      <span className="hidden xs:inline">Connect Wallet</span>
    </Button>
  )
} 