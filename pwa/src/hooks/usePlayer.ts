'use client'

import { createContext, useContext } from 'react'
import type { Video } from '@/types'

export interface PlayerContextType {
  currentVideo: Video | null
  queueEntryId: string | null
  isPlaying: boolean
  speed: number
  play: (video: Video, queueEntryId?: string) => void
  stop: () => void
  setSpeed: (speed: number) => void
  onEnded: () => void
}

export const PlayerContext = createContext<PlayerContextType>({
  currentVideo: null,
  queueEntryId: null,
  isPlaying: false,
  speed: 1,
  play: () => {},
  stop: () => {},
  setSpeed: () => {},
  onEnded: () => {},
})

export function usePlayer() {
  return useContext(PlayerContext)
}
