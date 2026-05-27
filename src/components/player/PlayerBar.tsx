'use client'

import { useState } from 'react'
import { usePlayer } from '@/hooks/usePlayer'
import VideoPlayer from './VideoPlayer'
import { formatDuration } from '@/lib/utils'

const SPEEDS = [0.5, 0.75, 1, 1.25, 1.5, 1.75, 2, 2.5, 3]

export default function PlayerBar() {
  const { currentVideo, speed, stop, setSpeed, onEnded } = usePlayer()
  const [expanded, setExpanded] = useState(false)

  if (!currentVideo) return null

  return (
    <>
      {/* Full-screen player modal */}
      {expanded && (
        <div className="fixed inset-0 z-50 bg-black flex flex-col">
          <div className="flex items-center justify-between p-4">
            <button
              onClick={() => setExpanded(false)}
              className="text-zinc-400 hover:text-white p-1"
              aria-label="Minimize player"
            >
              ▼
            </button>
            <button
              onClick={() => { stop(); setExpanded(false) }}
              className="text-zinc-400 hover:text-white text-sm"
            >
              Close
            </button>
          </div>
          <VideoPlayer video={currentVideo} speed={speed} onEnded={() => { onEnded(); setExpanded(false) }} />
          <div className="flex-1 overflow-y-auto p-4 space-y-4">
            <h2 className="font-semibold text-lg leading-snug">{currentVideo.title}</h2>
            <div>
              <p className="text-xs text-zinc-500 mb-2">Playback speed</p>
              <div className="flex gap-2 flex-wrap">
                {SPEEDS.map((s) => (
                  <button
                    key={s}
                    onClick={() => setSpeed(s)}
                    className={`px-3 py-1 rounded-full text-sm ${speed === s ? 'bg-white text-black' : 'bg-zinc-800 text-white'}`}
                  >
                    {s}×
                  </button>
                ))}
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Mini player bar */}
      {!expanded && (
        <button
          onClick={() => setExpanded(true)}
          className="fixed bottom-16 inset-x-0 z-40 mx-2 mb-1 flex items-center gap-3 bg-zinc-900 border border-zinc-700 rounded-xl px-3 py-2 shadow-lg hover:bg-zinc-800 transition-colors text-left"
        >
          {currentVideo.thumbnail_url && (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              src={currentVideo.thumbnail_url}
              alt=""
              className="w-12 h-9 object-cover rounded flex-shrink-0"
            />
          )}
          <div className="flex-1 min-w-0">
            <p className="text-sm font-medium truncate">{currentVideo.title}</p>
            {currentVideo.duration && (
              <p className="text-xs text-zinc-500">{formatDuration(currentVideo.duration)}</p>
            )}
          </div>
          <span className="text-zinc-400 text-xs">{speed}×</span>
        </button>
      )}
    </>
  )
}
