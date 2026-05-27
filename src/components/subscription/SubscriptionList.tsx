'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import type { Subscription } from '@/types'
import { formatRelativeDate } from '@/lib/utils'

interface Props {
  initialSubs: Subscription[]
}

export default function SubscriptionList({ initialSubs }: Props) {
  const [subs, setSubs] = useState(initialSubs)
  const [refreshing, setRefreshing] = useState<string | 'all' | null>(null)
  const [deleting, setDeleting] = useState<string | null>(null)
  const router = useRouter()

  async function refreshSub(subId?: string) {
    const key = subId ?? 'all'
    setRefreshing(key)
    const url = subId ? `/api/refresh?subscriptionId=${subId}` : '/api/refresh'
    await fetch(url, { method: 'POST' })
    router.refresh()
    setRefreshing(null)
  }

  async function deleteSub(subId: string) {
    setDeleting(subId)
    await fetch(`/api/subscriptions/${subId}`, { method: 'DELETE' })
    setSubs((prev) => prev.filter((s) => s.id !== subId))
    setDeleting(null)
  }

  if (!subs.length) {
    return (
      <div className="flex flex-col items-center justify-center py-16 text-zinc-600 px-8 text-center">
        <p className="font-medium">No subscriptions yet</p>
        <p className="text-sm mt-1">Add a YouTube channel above to get started</p>
      </div>
    )
  }

  return (
    <div>
      <div className="px-3 py-2 flex items-center justify-between">
        <p className="text-sm text-zinc-500">{subs.length} subscriptions</p>
        <button
          onClick={() => refreshSub()}
          disabled={refreshing !== null}
          className="text-xs bg-zinc-800 hover:bg-zinc-700 disabled:opacity-40 px-3 py-1.5 rounded-lg transition-colors"
        >
          {refreshing === 'all' ? 'Refreshing…' : '↻ Refresh all'}
        </button>
      </div>
      <div className="space-y-1 px-3">
        {subs.map((sub) => (
          <div key={sub.id} className="flex items-center gap-3 bg-zinc-900 rounded-xl px-3 py-2.5">
            {sub.thumbnail_url ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={sub.thumbnail_url} alt="" className="w-10 h-10 rounded-full object-cover flex-shrink-0" />
            ) : (
              <div className="w-10 h-10 rounded-full bg-zinc-800 flex-shrink-0" />
            )}
            <div className="flex-1 min-w-0">
              <p className="text-sm font-medium truncate">{sub.title}</p>
              {sub.most_recent_video_date && (
                <p className="text-xs text-zinc-600">Last video {formatRelativeDate(sub.most_recent_video_date)}</p>
              )}
            </div>
            <div className="flex gap-2 flex-shrink-0">
              <button
                onClick={() => refreshSub(sub.id)}
                disabled={refreshing !== null}
                className="text-xs text-zinc-400 hover:text-white disabled:opacity-40 p-1 transition-colors"
                aria-label="Refresh"
              >
                {refreshing === sub.id ? '…' : '↻'}
              </button>
              <button
                onClick={() => deleteSub(sub.id)}
                disabled={deleting === sub.id}
                className="text-xs text-red-500 hover:text-red-400 disabled:opacity-40 p-1 transition-colors"
                aria-label="Remove"
              >
                ✕
              </button>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
