'use client'

import { useState, useCallback } from 'react'
import { PlayerContext } from '@/hooks/usePlayer'
import BottomNav from './BottomNav'
import PlayerBar from '@/components/player/PlayerBar'
import type { Video } from '@/types'

export default function AppShell({ children, defaultSpeed }: { children: React.ReactNode; defaultSpeed: number }) {
  const [currentVideo, setCurrentVideo] = useState<Video | null>(null)
  const [queueEntryId, setQueueEntryId] = useState<string | null>(null)
  const [speed, setSpeed] = useState(defaultSpeed)

  const play = useCallback((video: Video, entryId?: string) => {
    setCurrentVideo(video)
    setQueueEntryId(entryId ?? null)
  }, [])

  const stop = useCallback(() => {
    setCurrentVideo(null)
    setQueueEntryId(null)
  }, [])

  const onEnded = useCallback(() => {
    // Pages can override by providing a callback; for now just stop
    setCurrentVideo(null)
    setQueueEntryId(null)
  }, [])

  return (
    <PlayerContext.Provider value={{ currentVideo, queueEntryId, isPlaying: !!currentVideo, speed, play, stop, setSpeed, onEnded }}>
      <div className="flex flex-col min-h-screen">
        <main className="flex-1 pb-32">
          {children}
        </main>
        <PlayerBar />
        <BottomNav />
      </div>
    </PlayerContext.Provider>
  )
}
