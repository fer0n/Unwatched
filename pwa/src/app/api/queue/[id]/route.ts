import { NextRequest } from 'next/server'
import { createClient } from '@/lib/supabase/server'

// PATCH: action=moveUp | moveDown | markWatched | addToQueue (from inbox)
export async function PATCH(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return Response.json({ error: 'Unauthorized' }, { status: 401 })

  const { id } = await params
  const { action } = await request.json()

  if (action === 'markWatched') {
    // Get the video_id for this queue entry
    const { data: entry } = await supabase
      .from('queue_entries')
      .select('video_id')
      .eq('id', id)
      .eq('user_id', user.id)
      .single()

    if (!entry) return Response.json({ error: 'Not found' }, { status: 404 })

    await supabase
      .from('videos')
      .update({ watched_date: new Date().toISOString(), elapsed_seconds: 0 })
      .eq('id', entry.video_id)

    await supabase.from('queue_entries').delete().eq('id', id).eq('user_id', user.id)
    return Response.json({ ok: true })
  }

  if (action === 'moveUp' || action === 'moveDown') {
    const { data: entry } = await supabase
      .from('queue_entries')
      .select('sort_order')
      .eq('id', id)
      .eq('user_id', user.id)
      .single()

    if (!entry) return Response.json({ error: 'Not found' }, { status: 404 })

    const currentOrder = entry.sort_order
    const direction = action === 'moveUp' ? -1 : 1

    // Find the adjacent entry
    const { data: adjacent } = await supabase
      .from('queue_entries')
      .select('id, sort_order')
      .eq('user_id', user.id)
      .order('sort_order', { ascending: direction === 1 })
      .gt('sort_order', direction === 1 ? currentOrder : -Infinity)
      .lt('sort_order', direction === -1 ? currentOrder : Infinity)
      .limit(1)
      .maybeSingle()

    if (!adjacent) return Response.json({ ok: true }) // already at edge

    // Swap sort_orders
    await supabase
      .from('queue_entries')
      .update({ sort_order: adjacent.sort_order })
      .eq('id', id)
      .eq('user_id', user.id)

    await supabase
      .from('queue_entries')
      .update({ sort_order: currentOrder })
      .eq('id', adjacent.id)
      .eq('user_id', user.id)

    return Response.json({ ok: true })
  }

  return Response.json({ error: 'Unknown action' }, { status: 400 })
}

export async function DELETE(
  _req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return Response.json({ error: 'Unauthorized' }, { status: 401 })

  const { id } = await params
  const { error } = await supabase
    .from('queue_entries')
    .delete()
    .eq('id', id)
    .eq('user_id', user.id)

  if (error) return Response.json({ error: error.message }, { status: 500 })
  return new Response(null, { status: 204 })
}
