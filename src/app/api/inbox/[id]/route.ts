import { NextRequest } from 'next/server'
import { createClient } from '@/lib/supabase/server'

// PATCH: action=addToQueueTop | addToQueueBottom
export async function PATCH(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return Response.json({ error: 'Unauthorized' }, { status: 401 })

  const { id } = await params
  const { action } = await request.json()

  const { data: entry } = await supabase
    .from('inbox_entries')
    .select('video_id')
    .eq('id', id)
    .eq('user_id', user.id)
    .single()

  if (!entry) return Response.json({ error: 'Not found' }, { status: 404 })

  // Check if already in queue
  const { data: alreadyQueued } = await supabase
    .from('queue_entries')
    .select('id')
    .eq('user_id', user.id)
    .eq('video_id', entry.video_id)
    .maybeSingle()

  if (!alreadyQueued) {
    if (action === 'addToQueueTop') {
      // Shift all existing queue entries down by 1
      await supabase.rpc('queue_shift_down', { p_user_id: user.id })
      await supabase.from('queue_entries').insert({
        user_id: user.id,
        video_id: entry.video_id,
        sort_order: 0,
      })
    } else {
      // addToQueueBottom — append at end
      const { data: maxRow } = await supabase
        .from('queue_entries')
        .select('sort_order')
        .eq('user_id', user.id)
        .order('sort_order', { ascending: false })
        .limit(1)
        .maybeSingle()

      await supabase.from('queue_entries').insert({
        user_id: user.id,
        video_id: entry.video_id,
        sort_order: (maxRow?.sort_order ?? -1) + 1,
      })
    }
  }

  // Remove from inbox
  await supabase.from('inbox_entries').delete().eq('id', id).eq('user_id', user.id)
  return Response.json({ ok: true })
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
    .from('inbox_entries')
    .delete()
    .eq('id', id)
    .eq('user_id', user.id)

  if (error) return Response.json({ error: error.message }, { status: 500 })
  return new Response(null, { status: 204 })
}
