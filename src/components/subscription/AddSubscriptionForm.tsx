'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'

export default function AddSubscriptionForm() {
  const [url, setUrl] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const router = useRouter()

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError('')
    setLoading(true)
    const res = await fetch('/api/subscriptions', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ url }),
    })
    const data = await res.json()
    if (!res.ok) {
      setError(data.error ?? 'Something went wrong')
    } else {
      setUrl('')
      router.refresh()
    }
    setLoading(false)
  }

  return (
    <form onSubmit={handleSubmit} className="p-3 space-y-2">
      <p className="text-xs text-zinc-500">Paste a YouTube channel URL, @handle, or playlist URL</p>
      <div className="flex gap-2">
        <input
          value={url}
          onChange={(e) => setUrl(e.target.value)}
          placeholder="https://youtube.com/@channel"
          required
          className="flex-1 bg-zinc-900 border border-zinc-700 rounded-lg px-3 py-2 text-sm text-white placeholder-zinc-600 focus:outline-none focus:border-zinc-400"
        />
        <button
          type="submit"
          disabled={loading}
          className="bg-white text-black text-sm font-semibold px-4 py-2 rounded-lg hover:bg-zinc-200 disabled:opacity-50 transition-colors"
        >
          {loading ? '…' : 'Add'}
        </button>
      </div>
      {error && <p className="text-red-400 text-xs">{error}</p>}
    </form>
  )
}
