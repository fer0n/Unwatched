import { createClient } from '@/lib/supabase/server'
import AppShell from '@/components/layout/AppShell'
import InboxList from '@/components/inbox/InboxList'

export default async function InboxPage() {
  const supabase = await createClient()

  const [{ data: entries }, { data: settings }] = await Promise.all([
    supabase
      .from('inbox_entries')
      .select('*, video:videos(*, subscription:subscriptions(title, thumbnail_url))')
      .order('created_at', { ascending: false }),
    supabase.from('user_settings').select('default_playback_speed').maybeSingle(),
  ])

  return (
    <AppShell defaultSpeed={settings?.default_playback_speed ?? 1}>
      <div className="px-3 pt-4 pb-2 flex items-center justify-between">
        <h1 className="text-xl font-bold">Inbox</h1>
        <span className="text-sm text-zinc-500">{entries?.length ?? 0} videos</span>
      </div>
      <InboxList initialEntries={entries ?? []} />
    </AppShell>
  )
}
