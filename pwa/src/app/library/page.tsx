import { createClient } from '@/lib/supabase/server'
import AppShell from '@/components/layout/AppShell'
import AddSubscriptionForm from '@/components/subscription/AddSubscriptionForm'
import SubscriptionList from '@/components/subscription/SubscriptionList'

export default async function LibraryPage() {
  const supabase = await createClient()

  const [{ data: subs }, { data: settings }] = await Promise.all([
    supabase
      .from('subscriptions')
      .select('*')
      .eq('is_archived', false)
      .order('title'),
    supabase.from('user_settings').select('default_playback_speed').maybeSingle(),
  ])

  return (
    <AppShell defaultSpeed={settings?.default_playback_speed ?? 1}>
      <div className="px-3 pt-4 pb-2">
        <h1 className="text-xl font-bold">Library</h1>
      </div>
      <AddSubscriptionForm />
      <SubscriptionList initialSubs={subs ?? []} />
    </AppShell>
  )
}
