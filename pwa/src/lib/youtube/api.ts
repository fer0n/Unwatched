// YouTube Data API v3 helpers

const BASE = 'https://www.googleapis.com/youtube/v3'

function key() {
  const k = process.env.YOUTUBE_API_KEY
  if (!k) throw new Error('Missing YOUTUBE_API_KEY')
  return k
}

export interface ChannelInfo {
  channelId: string
  title: string
  thumbnailUrl: string | null
}

export async function resolveHandle(handle: string): Promise<ChannelInfo | null> {
  const res = await fetch(
    `${BASE}/channels?part=id,snippet&forHandle=${encodeURIComponent(handle)}&key=${key()}`,
    { next: { revalidate: 3600 } }
  )
  if (!res.ok) return null
  const data = await res.json()
  const item = data.items?.[0]
  if (!item) return null
  return {
    channelId: item.id,
    title: item.snippet.title,
    thumbnailUrl: item.snippet.thumbnails?.default?.url ?? null,
  }
}

export async function getChannelById(channelId: string): Promise<ChannelInfo | null> {
  const res = await fetch(
    `${BASE}/channels?part=id,snippet&id=${encodeURIComponent(channelId)}&key=${key()}`,
    { next: { revalidate: 3600 } }
  )
  if (!res.ok) return null
  const data = await res.json()
  const item = data.items?.[0]
  if (!item) return null
  return {
    channelId: item.id,
    title: item.snippet.title,
    thumbnailUrl: item.snippet.thumbnails?.default?.url ?? null,
  }
}
