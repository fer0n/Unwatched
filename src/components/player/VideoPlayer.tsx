'use client'

import { useEffect, useRef, useCallback } from 'react'
import { buildEmbedUrl } from '@/lib/youtube/url'
import type { Video } from '@/types'
import { createClient } from '@/lib/supabase/client'

declare global {
  interface Window {
    YT: {
      Player: new (el: HTMLElement, opts: Record<string, unknown>) => YTPlayer
      PlayerState: { PLAYING: number; PAUSED: number; ENDED: number }
    }
    onYouTubeIframeAPIReady: () => void
  }
}

interface YTPlayer {
  setPlaybackRate(rate: number): void
  getCurrentTime(): number
  getDuration(): number
  playVideo(): void
  pauseVideo(): void
  seekTo(seconds: number, allowSeekAhead: boolean): void
  destroy(): void
}

interface Props {
  video: Video
  speed: number
  onEnded: () => void
  onReady?: () => void
}

let apiLoaded = false

function loadYTApi(): Promise<void> {
  if (apiLoaded) return Promise.resolve()
  return new Promise((resolve) => {
    const script = document.createElement('script')
    script.src = 'https://www.youtube.com/iframe_api'
    document.head.appendChild(script)
    window.onYouTubeIframeAPIReady = () => {
      apiLoaded = true
      resolve()
    }
  })
}

export default function VideoPlayer({ video, speed, onEnded, onReady }: Props) {
  const containerRef = useRef<HTMLDivElement>(null)
  const playerRef = useRef<YTPlayer | null>(null)
  const pollRef = useRef<ReturnType<typeof setInterval> | null>(null)
  const supabase = createClient()

  const saveProgress = useCallback(async (seconds: number) => {
    if (seconds < 2) return
    await supabase
      .from('videos')
      .update({ elapsed_seconds: seconds })
      .eq('id', video.id)
  }, [video.id, supabase])

  const markWatched = useCallback(async () => {
    await supabase
      .from('videos')
      .update({ watched_date: new Date().toISOString(), elapsed_seconds: 0 })
      .eq('id', video.id)
  }, [video.id, supabase])

  useEffect(() => {
    let destroyed = false
    let player: YTPlayer | null = null

    async function init() {
      await loadYTApi()
      if (destroyed || !containerRef.current) return

      // Clear any previous iframe
      containerRef.current.innerHTML = ''
      const el = document.createElement('div')
      containerRef.current.appendChild(el)

      player = new window.YT.Player(el, {
        videoId: video.youtube_id,
        playerVars: {
          start: Math.floor(video.elapsed_seconds ?? 0),
          autoplay: 1,
          color: 'white',
          iv_load_policy: 3,
          rel: 0,
        },
        events: {
          onReady: (event: { target: YTPlayer }) => {
            if (destroyed) return
            event.target.setPlaybackRate(speed)
            playerRef.current = event.target
            onReady?.()
          },
          onStateChange: async (event: { data: number }) => {
            const { PAUSED, ENDED } = window.YT.PlayerState
            if (event.data === PAUSED) {
              const t = player?.getCurrentTime() ?? 0
              await saveProgress(t)
            }
            if (event.data === ENDED) {
              await markWatched()
              onEnded()
            }
          },
        },
      })
    }

    init()

    // Poll every 3s to save progress while playing
    pollRef.current = setInterval(async () => {
      const p = playerRef.current
      if (!p) return
      const state = (p as unknown as { getPlayerState(): number }).getPlayerState?.()
      if (state === 1 /* PLAYING */) {
        await saveProgress(p.getCurrentTime())
      }
    }, 3000)

    return () => {
      destroyed = true
      if (pollRef.current) clearInterval(pollRef.current)
      player?.destroy()
      playerRef.current = null
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [video.youtube_id])

  // Apply speed changes without recreating player
  useEffect(() => {
    playerRef.current?.setPlaybackRate(speed)
  }, [speed])

  return (
    <div ref={containerRef} className="w-full aspect-video bg-black" />
  )
}
