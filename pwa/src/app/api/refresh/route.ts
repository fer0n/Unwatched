import { NextRequest } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createServiceClient } from '@/lib/supabase/server'
import { parseFeed } from '@/lib/youtube/rss'

export async function POST(request: NextRequest) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return Response.json({ error: 'Unauthorized' }, { status: 401 })

  const url = new URL(request.url)
  const subscriptionId = url.searchParams.get('subscriptionId')

  // Use service client for upserts (bypasses RLS for batch ops)
  const service = createServiceClient()

  // Fetch settings for triage logic
  const { data: settings } = await supabase
    .from('user_settings')
    .select('default_video_placement, hide_shorts')
    .eq('user_id', user.id)
    .maybeSingle()

  const placement = settings?.default_video_placement ?? 0
  const hideShorts = settings?.hide_shorts ?? false

  // Fetch subscriptions to refresh
  const query = supabase
    .from('subscriptions')
    .select('id, feed_url, most_recent_video_date')
    .eq('user_id', user.id)
    .eq('is_archived', false)

  if (subscriptionId) query.eq('id', subscriptionId)

  const { data: subs, error: subsError } = await query
  if (subsError) return Response.json({ error: subsError.message }, { status: 500 })
  if (!subs?.length) return Response.json({ added: 0 })

  let totalAdded = 0

  for (const sub of subs) {
    const entries = await parseFeed(sub.feed_url)
    if (!entries.length) continue

    // Get existing youtube_ids for this user to skip duplicates
    const ytIds = entries.map((e) => e.youtubeId)
    const { data: existing } = await supabase
      .from('videos')
      .select('youtube_id')
      .eq('user_id', user.id)
      .in('youtube_id', ytIds)

    const existingIds = new Set((existing ?? []).map((v) => v.youtube_id))
    const newEntries = entries.filter((e) => !existingIds.has(e.youtubeId))

    if (!newEntries.length) continue

    // Filter shorts if needed
    const toInsert = hideShorts ? newEntries.filter((e) => !e.isYtShort) : newEntries

    if (!toInsert.length) continue

    // Insert videos
    const videoRows = toInsert.map((e) => ({
      user_id: user.id,
      subscription_id: sub.id,
      youtube_id: e.youtubeId,
      title: e.title,
      thumbnail_url: e.thumbnailUrl,
      published_date: e.publishedDate,
      is_yt_short: e.isYtShort,
    }))

    const { data: insertedVideos, error: insertError } = await service
      .from('videos')
      .insert(videoRows)
      .select('id, youtube_id, published_date')

    if (insertError) continue

    // Triage: insert into inbox or queue
    if (placement === 1) {
      // Queue: get current max sort_order
      const { data: maxRow } = await supabase
        .from('queue_entries')
        .select('sort_order')
        .eq('user_id', user.id)
        .order('sort_order', { ascending: false })
        .limit(1)
        .maybeSingle()

      let order = (maxRow?.sort_order ?? -1) + 1
      const queueRows = (insertedVideos ?? []).map((v) => ({
        user_id: user.id,
        video_id: v.id,
        sort_order: order++,
      }))
      await service.from('queue_entries').insert(queueRows)
    } else {
      // Inbox (default)
      const inboxRows = (insertedVideos ?? []).map((v) => ({
        user_id: user.id,
        video_id: v.id,
      }))
      await service.from('inbox_entries').insert(inboxRows)
    }

    totalAdded += insertedVideos?.length ?? 0

    // Update most_recent_video_date
    const latestDate = toInsert
      .map((e) => e.publishedDate)
      .filter(Boolean)
      .sort()
      .at(-1)

    if (latestDate) {
      await service
        .from('subscriptions')
        .update({ most_recent_video_date: latestDate })
        .eq('id', sub.id)
    }
  }

  return Response.json({ added: totalAdded })
}
