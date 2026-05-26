// Mirrors UrlService.swift logic for parsing YouTube URLs

export interface ParsedYouTubeUrl {
  type: 'video' | 'channel' | 'playlist' | 'handle' | 'unknown'
  youtubeId?: string      // for video
  channelId?: string      // for channel
  playlistId?: string     // for playlist
  handle?: string         // @handle, /c/name, /user/name — needs API resolution
}

export function parseYouTubeUrl(input: string): ParsedYouTubeUrl {
  const raw = input.trim()
  let url: URL

  try {
    url = new URL(raw.startsWith('http') ? raw : `https://${raw}`)
  } catch {
    // Treat bare channel handle like @mkbhd
    if (raw.startsWith('@')) {
      return { type: 'handle', handle: raw.slice(1) }
    }
    return { type: 'unknown' }
  }

  const host = url.hostname.replace('www.', '')
  if (host !== 'youtube.com' && host !== 'youtu.be' && host !== 'm.youtube.com') {
    return { type: 'unknown' }
  }

  const path = url.pathname

  // Short link: youtu.be/{id}
  if (host === 'youtu.be') {
    const id = path.slice(1).split('/')[0]
    if (id) return { type: 'video', youtubeId: id }
  }

  // Video: /watch?v={id}
  const v = url.searchParams.get('v')
  if (v) return { type: 'video', youtubeId: v }

  // Shorts: /shorts/{id}
  const shortsMatch = path.match(/^\/shorts\/([^/?]+)/)
  if (shortsMatch) return { type: 'video', youtubeId: shortsMatch[1] }

  // Embed: /embed/{id}
  const embedMatch = path.match(/^\/embed\/([^/?]+)/)
  if (embedMatch) return { type: 'video', youtubeId: embedMatch[1] }

  // Channel ID: /channel/{id}
  const channelMatch = path.match(/^\/channel\/([^/?]+)/)
  if (channelMatch) return { type: 'channel', channelId: channelMatch[1] }

  // Playlist
  const list = url.searchParams.get('list')
  if (list && path.includes('playlist')) return { type: 'playlist', playlistId: list }

  // Handle-based: /@handle, /c/name, /user/name
  const handleMatch = path.match(/^\/@([^/?]+)/)
  if (handleMatch) return { type: 'handle', handle: handleMatch[1] }

  const cMatch = path.match(/^\/c\/([^/?]+)/)
  if (cMatch) return { type: 'handle', handle: cMatch[1] }

  const userMatch = path.match(/^\/user\/([^/?]+)/)
  if (userMatch) return { type: 'handle', handle: userMatch[1] }

  return { type: 'unknown' }
}

export function buildRssUrl(channelId?: string, playlistId?: string): string | null {
  if (channelId) {
    return `https://www.youtube.com/feeds/videos.xml?channel_id=${channelId}`
  }
  if (playlistId) {
    return `https://www.youtube.com/feeds/videos.xml?playlist_id=${playlistId}`
  }
  return null
}

export function buildEmbedUrl(youtubeId: string, startSeconds = 0): string {
  const t = startSeconds > 5 ? `&t=${Math.floor(startSeconds)}s` : ''
  return `https://www.youtube.com/embed/${youtubeId}?enablejsapi=1&color=white&iv_load_policy=3&rel=0${t}`
}

export function isYtShort(videoUrl: string, title: string): boolean {
  if (videoUrl.includes('/shorts/')) return true
  if (/\s#shorts\b/i.test(title)) return true
  return false
}
