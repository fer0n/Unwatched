'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import type { UserSettings } from '@/types'

const SPEEDS = [0.5, 0.75, 1, 1.25, 1.5, 1.75, 2, 2.5, 3]

interface Props {
  initialSettings: Omit<UserSettings, 'user_id'>
  email: string
}

export default function SettingsForm({ initialSettings, email }: Props) {
  const [settings, setSettings] = useState(initialSettings)
  const [saving, setSaving] = useState(false)
  const [saved, setSaved] = useState(false)
  const router = useRouter()

  async function save() {
    setSaving(true)
    const supabase = createClient()
    await supabase.from('user_settings').upsert(settings)
    setSaved(true)
    setTimeout(() => setSaved(false), 2000)
    setSaving(false)
    router.refresh()
  }

  async function signOut() {
    const supabase = createClient()
    await supabase.auth.signOut()
    router.push('/login')
    router.refresh()
  }

  return (
    <div className="px-3 space-y-6 pb-8">
      <Section title="Playback">
        <FieldLabel>Default speed</FieldLabel>
        <div className="flex gap-2 flex-wrap mt-1">
          {SPEEDS.map((s) => (
            <button
              key={s}
              onClick={() => setSettings((p) => ({ ...p, default_playback_speed: s }))}
              className={`px-3 py-1 rounded-full text-sm transition-colors ${
                settings.default_playback_speed === s ? 'bg-white text-black' : 'bg-zinc-800 text-white'
              }`}
            >
              {s}×
            </button>
          ))}
        </div>
      </Section>

      <Section title="New videos">
        <FieldLabel>Default placement</FieldLabel>
        <div className="flex gap-2 mt-1">
          {(['Inbox', 'Queue'] as const).map((label, i) => (
            <button
              key={label}
              onClick={() => setSettings((p) => ({ ...p, default_video_placement: i as 0 | 1 }))}
              className={`px-4 py-1.5 rounded-full text-sm transition-colors ${
                settings.default_video_placement === i ? 'bg-white text-black' : 'bg-zinc-800 text-white'
              }`}
            >
              {label}
            </button>
          ))}
        </div>

        <div className="flex items-center justify-between mt-4">
          <div>
            <p className="text-sm">Hide Shorts</p>
            <p className="text-xs text-zinc-500">Skip YouTube Shorts when refreshing</p>
          </div>
          <button
            onClick={() => setSettings((p) => ({ ...p, hide_shorts: !p.hide_shorts }))}
            className={`w-12 h-6 rounded-full transition-colors relative ${settings.hide_shorts ? 'bg-white' : 'bg-zinc-700'}`}
          >
            <span
              className={`absolute top-0.5 w-5 h-5 rounded-full bg-black transition-transform ${
                settings.hide_shorts ? 'translate-x-6' : 'translate-x-0.5'
              }`}
            />
          </button>
        </div>
      </Section>

      <button
        onClick={save}
        disabled={saving}
        className="w-full bg-white text-black font-semibold py-2.5 rounded-xl hover:bg-zinc-200 disabled:opacity-50 transition-colors"
      >
        {saving ? 'Saving…' : saved ? 'Saved ✓' : 'Save settings'}
      </button>

      <Section title="Account">
        <p className="text-sm text-zinc-400">{email}</p>
        <button
          onClick={signOut}
          className="mt-3 text-sm text-red-400 hover:text-red-300 transition-colors"
        >
          Sign out
        </button>
      </Section>
    </div>
  )
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div>
      <h2 className="text-xs text-zinc-500 uppercase tracking-wide mb-3">{title}</h2>
      <div className="bg-zinc-900 rounded-xl p-4">{children}</div>
    </div>
  )
}

function FieldLabel({ children }: { children: React.ReactNode }) {
  return <p className="text-sm text-zinc-300">{children}</p>
}
