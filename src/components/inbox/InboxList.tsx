'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import VideoListItem from '@/components/video/VideoListItem'
import { usePlayer } from '@/hooks/usePlayer'
import type { InboxEntry } from '@/types'

interface Props {
  initialEntries: InboxEntry[]
}

export default function InboxList({ initialEntries }: Props) {
  const [entries, setEntries] = useState(initialEntries)
  const [loading, setLoading] = useState<string | null>(null)
  const { play } = usePlayer()
  const router = useRouter()

  async function addToQueue(entryId: string, position: 'addToQueueTop' | 'addToQueueBottom') {
    setLoading(entryId)
    await fetch(`/api/inbox/${entryId}`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ action: position }),
    })
    setEntries((prev) => prev.filter((e) => e.id !== entryId))
    router.refresh()
    setLoading(null)
  }

  async function dismiss(entryId: string) {
    setLoading(entryId)
    await fetch(`/api/inbox/${entryId}`, { method: 'DELETE' })
    setEntries((prev) => prev.filter((e) => e.id !== entryId))
    setLoading(null)
  }

  if (!entries.length) {
    return (
      <div className="flex flex-col items-center justify-center py-24 text-zinc-600 px-8 text-center">
        <p className="text-4xl mb-4">⊹</p>
        <p className="font-medium">Inbox is empty</p>
        <p className="text-sm mt-1">Refresh your subscriptions to find new videos</p>
      </div>
    )
  }

  return (
    <div className="space-y-2 px-3">
      {entries.map((entry) => {
        const video = entry.video
        if (!video) return null
        return (
          <VideoListItem
            key={entry.id}
            video={video}
            onPlay={() => play(video)}
            actions={
              <>
                <ActionBtn disabled={loading === entry.id} onClick={() => addToQueue(entry.id, 'addToQueueTop')} label="+ Queue top" />
                <ActionBtn disabled={loading === entry.id} onClick={() => addToQueue(entry.id, 'addToQueueBottom')} label="+ Queue" />
                <ActionBtn disabled={loading === entry.id} onClick={() => dismiss(entry.id)} label="Dismiss" />
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
