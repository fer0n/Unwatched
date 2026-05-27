'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'

const tabs = [
  { href: '/queue', label: 'Queue', icon: '≡' },
  { href: '/inbox', label: 'Inbox', icon: '⊹' },
  { href: '/library', label: 'Library', icon: '⊞' },
  { href: '/settings', label: 'Settings', icon: '⚙' },
]

export default function BottomNav() {
  const pathname = usePathname()

  return (
    <nav className="fixed bottom-0 inset-x-0 z-50 bg-zinc-950 border-t border-zinc-800 flex safe-area-bottom">
      {tabs.map(({ href, label, icon }) => {
        const active = pathname.startsWith(href)
        return (
          <Link
            key={href}
            href={href}
            className={`flex-1 flex flex-col items-center gap-1 py-2 text-xs transition-colors ${
              active ? 'text-white' : 'text-zinc-500 hover:text-zinc-300'
            }`}
          >
            <span className="text-lg leading-none">{icon}</span>
            <span>{label}</span>
          </Link>
        )
      })}
    </nav>
  )
}
