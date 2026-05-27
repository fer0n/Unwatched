import { createClient } from '@/lib/supabase/server'
import AppShell from '@/components/layout/AppShell'
import QueueList from '@/components/queue/QueueList'

export default async function QueuePage() {
  const supabase = await createClient()

  const [{ data: entries }, { data: settings }] = await Promise.all([
    supabase
      .from('queue_entries')
      .select('*, video:videos(*, subscription:subscriptions(title, thumbnail_url))')
      .order('sort_order'),
    supabase.from('user_settings').select('default_playback_speed').maybeSingle(),
  ])

  return (
    <AppShell defaultSpeed={settings?.default_playback_speed ?? 1}>
      <div className="px-3 pt-4 pb-2 flex items-center justify-between">
        <h1 className="text-xl font-bold">Queue</h1>
        <span className="text-sm text-zinc-500">{entries?.length ?? 0} videos</span>
      </div>
      <QueueList initialEntries={entries ?? []} />
    </AppShell>
  )
}
