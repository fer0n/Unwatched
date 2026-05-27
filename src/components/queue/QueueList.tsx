'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import VideoListItem from '@/components/video/VideoListItem'
import { usePlayer } from '@/hooks/usePlayer'
import type { QueueEntry } from '@/types'

interface Props {
  initialEntries: QueueEntry[]
}

export default function QueueList({ initialEntries }: Props) {
  const [entries, setEntries] = useState(initialEntries)
  const [loading, setLoading] = useState<string | null>(null)
  const { play } = usePlayer()
  const router = useRouter()

  async function apiAction(entryId: string, method: string, body?: unknown) {
    setLoading(entryId)
    await fetch(`/api/queue/${entryId}`, {
      method,
      headers: { 'Content-Type': 'application/json' },
      body: body ? JSON.stringify(body) : undefined,
    })
    router.refresh()
    setLoading(null)
  }

  async function move(entryId: string, direction: 'moveUp' | 'moveDown') {
    await apiAction(entryId, 'PATCH', { action: direction })
    // Optimistic reorder
    setEntries((prev) => {
      const idx = prev.findIndex((e) => e.id === entryId)
      if (idx < 0) return prev
      const swapIdx = direction === 'moveUp' ? idx - 1 : idx + 1
      if (swapIdx < 0 || swapIdx >= prev.length) return prev
      const next = [...prev]
      ;[next[idx], next[swapIdx]] = [next[swapIdx], next[idx]]
      return next
    })
  }

  async function markWatched(entryId: string) {
    await apiAction(entryId, 'PATCH', { action: 'markWatched' })
    setEntries((prev) => prev.filter((e) => e.id !== entryId))
  }

  async function removeFromQueue(entryId: string) {
    await apiAction(entryId, 'DELETE')
    setEntries((prev) => prev.filter((e) => e.id !== entryId))
  }

  if (!entries.length) {
    return (
      <div className="flex flex-col items-center justify-center py-24 text-zinc-600 px-8 text-center">
        <p className="text-4xl mb-4">≡</p>
        <p className="font-medium">Queue is empty</p>
        <p className="text-sm mt-1">Add videos from your inbox or subscriptions</p>
      </div>
    )
  }

  return (
    <div className="space-y-2 px-3">
      {entries.map((entry, i) => {
        const video = entry.video
        if (!video) return null
        return (
          <VideoListItem
            key={entry.id}
            video={video}
            position={i + 1}
            onPlay={() => play(video, entry.id)}
            actions={
              <>
                <ActionBtn disabled={loading === entry.id} onClick={() => move(entry.id, 'moveUp')} label="↑" />
                <ActionBtn disabled={loading === entry.id} onClick={() => move(entry.id, 'moveDown')} label="↓" />
                <ActionBtn disabled={loading === entry.id} onClick={() => markWatched(entry.id)} label="✓ Done" />
                <ActionBtn disabled={loading === entry.id} onClick={() => removeFromQueue(entry.id)} label="Remove" />
              </>
            }
          />
        )
      })}
    </div>
  )
}

function ActionBtn({ label, onClick, disabled }: { label: string; onClick: () => void; disabled?: boolean }) {
  return (
    <button
      onClick={onClick}
      disabled={disabled}
      className="text-xs bg-zinc-800 hover:bg-zinc-700 disabled:opacity-40 px-2 py-1 rounded-md transition-colors"
    >
      {label}
    </button>
  )
}
