'use client'

import { formatDuration, formatRelativeDate } from '@/lib/utils'
import type { Video } from '@/types'

interface Props {
  video: Video
  position?: number
  actions: React.ReactNode
  onPlay?: () => void
}

export default function VideoListItem({ video, position, actions, onPlay }: Props) {
  return (
    <div className="flex gap-3 p-3 bg-zinc-900 rounded-xl">
      <button
        onClick={onPlay}
        className="relative flex-shrink-0 w-28 aspect-video bg-zinc-800 rounded-lg overflow-hidden"
        disabled={!onPlay}
      >
        {video.thumbnail_url && (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={video.thumbnail_url}
            alt=""
            className="w-full h-full object-cover"
          />
        )}
        {video.duration && (
          <span className="absolute bottom-1 right-1 bg-black/80 text-white text-xs px-1 rounded">
            {formatDuration(video.duration)}
          </span>
        )}
        {position !== undefined && (
          <span className="absolute top-1 left-1 bg-black/80 text-white text-xs px-1.5 py-0.5 rounded-full font-mono">
            {position}
          </span>
        )}
      </button>
      <div className="flex-1 min-w-0 flex flex-col justify-between">
        <div>
          <p className="text-sm font-medium leading-snug line-clamp-2">{video.title}</p>
          {video.subscription?.title && (
            <p className="text-xs text-zinc-500 mt-0.5 truncate">{video.subscription.title}</p>
          )}
          <p className="text-xs text-zinc-600 mt-0.5">{formatRelativeDate(video.published_date)}</p>
        </div>
        <div className="flex gap-2 mt-2 flex-wrap">{actions}</div>
      </div>
    </div>
  )
}
