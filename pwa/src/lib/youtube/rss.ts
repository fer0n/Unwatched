// Mirrors RSSParserDelegate.swift — server-side only (YouTube feeds have no CORS)
import Parser from 'rss-parser'
import { isYtShort } from './url'

export interface ParsedVideo {
  youtubeId: string
  title: string
  thumbnailUrl: string | null
  publishedDate: string | null
  videoUrl: string
  isYtShort: boolean
}

const parser = new Parser({
  customFields: {
    item: [
      ['yt:videoId', 'youtubeId'],
      ['media:group', 'mediaGroup'],
    ],
  },
})

export async function parseFeed(feedUrl: string): Promise<ParsedVideo[]> {
  let feed
  try {
    const res = await fetch(feedUrl, { next: { revalidate: 0 } })
    if (!res.ok) return []
    const xml = await res.text()
    feed = await parser.parseString(xml)
  } catch {
    return []
  }

  return feed.items.map((item) => {
    const rawItem = item as unknown as Record<string, unknown>
    const youtubeId = rawItem.youtubeId as string ?? ''
    const link = item.link ?? ''
    const title = item.title ?? ''
    // Media thumbnail may be nested inside mediaGroup
    const mg = rawItem.mediaGroup as Record<string, unknown> | undefined
    const mediaThumbnail = mg?.['media:thumbnail'] as { $?: { url?: string } } | undefined
    const thumbnail = mediaThumbnail?.$?.url ?? null

    return {
      youtubeId,
      title,
      thumbnailUrl: thumbnail,
      publishedDate: item.pubDate ?? item.isoDate ?? null,
      videoUrl: link,
      isYtShort: isYtShort(link, title),
    }
  }).filter((v) => v.youtubeId)
}
