import { createClient } from '@/lib/supabase/server'
import AppShell from '@/components/layout/AppShell'
import SettingsForm from './SettingsForm'

export default async function SettingsPage() {
  const supabase = await createClient()

  const [{ data: settings }, { data: { user } }] = await Promise.all([
    supabase.from('user_settings').select('*').maybeSingle(),
    supabase.auth.getUser(),
  ])

  return (
    <AppShell defaultSpeed={settings?.default_playback_speed ?? 1}>
      <div className="px-3 pt-4 pb-2">
        <h1 className="text-xl font-bold">Settings</h1>
      </div>
      <SettingsForm
        initialSettings={settings ?? {
          default_playback_speed: 1,
          default_video_placement: 0,
          hide_shorts: false,
        }}
        email={user?.email ?? ''}
      />
    </AppShell>
  )
}
