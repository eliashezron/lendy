'use client'

import { http, createConfig } from 'wagmi'
import { celo, celoAlfajores } from 'wagmi/chains'

export const config = createConfig({
  chains: [celo, celoAlfajores],
  transports: {
    [celo.id]: http(),
    [celoAlfajores.id]: http(),
  },
})