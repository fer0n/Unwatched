import { NextRequest } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { parseYouTubeUrl, buildRssUrl } from '@/lib/youtube/url'
import { resolveHandle, getChannelById } from '@/lib/youtube/api'

export async function GET() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return Response.json({ error: 'Unauthorized' }, { status: 401 })

  const { data, error } = await supabase
    .from('subscriptions')
    .select('*')
    .eq('user_id', user.id)
    .eq('is_archived', false)
    .order('title')

  if (error) return Response.json({ error: error.message }, { status: 500 })
  return Response.json(data)
}

export async function POST(request: NextRequest) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return Response.json({ error: 'Unauthorized' }, { status: 401 })

  const { url } = await request.json()
  if (!url) return Response.json({ error: 'url is required' }, { status: 400 })

  const parsed = parseYouTubeUrl(url)
  let channelId: string | null = null
  let playlistId: string | null = null
  let title = '-'
  let thumbnailUrl: string | null = null

  if (parsed.type === 'channel') {
    channelId = parsed.channelId!
    const info = await getChannelById(channelId)
    if (info) { title = info.title; thumbnailUrl = info.thumbnailUrl }
  } else if (parsed.type === 'handle') {
    const info = await resolveHandle(parsed.handle!)
    if (!info) return Response.json({ error: 'Channel not found' }, { status: 404 })
    channelId = info.channelId
    title = info.title
    thumbnailUrl = info.thumbnailUrl
  } else if (parsed.type === 'playlist') {
    playlistId = parsed.playlistId!
    title = `Playlist ${playlistId}`
  } else {
    return Response.json({ error: 'Could not parse a channel or playlist from this URL' }, { status: 400 })
  }

  const feedUrl = buildRssUrl(channelId ?? undefined, playlistId ?? undefined)
  if (!feedUrl) return Response.json({ error: 'Could not build feed URL' }, { status: 400 })

  // Check for duplicate
  const { data: existing } = await supabase
    .from('subscriptions')
    .select('id')
    .eq('user_id', user.id)
    .eq('feed_url', feedUrl)
    .maybeSingle()

  if (existing) return Response.json({ error: 'Already subscribed' }, { status: 409 })

  const { data, error } = await supabase
    .from('subscriptions')
    .insert({
      user_id: user.id,
      title,
      youtube_channel_id: channelId,
      youtube_playlist_id: playlistId,
      feed_url: feedUrl,
      thumbnail_url: thumbnailUrl,
    })
    .select()
    .single()

  if (error) return Response.json({ error: error.message }, { status: 500 })
  return Response.json(data, { status: 201 })
}
