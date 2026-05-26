export interface Subscription {
  id: string
  user_id: string
  title: string
  youtube_channel_id: string | null
  youtube_playlist_id: string | null
  feed_url: string
  thumbnail_url: string | null
  subscribed_date: string
  most_recent_video_date: string | null
  is_archived: boolean
}

export interface Video {
  id: string
  user_id: string
  subscription_id: string | null
  youtube_id: string
  title: string
  thumbnail_url: string | null
  published_date: string | null
  duration: number | null
  elapsed_seconds: number
  watched_date: string | null
  is_yt_short: boolean
  created_at: string
  subscription?: Pick<Subscription, 'title' | 'thumbnail_url'>
}

export interface QueueEntry {
  id: string
  user_id: string
  video_id: string
  sort_order: number
  created_at: string
  video?: Video
}

export interface InboxEntry {
  id: string
  user_id: string
  video_id: string
  created_at: string
  video?: Video
}

export interface UserSettings {
  user_id: string
  default_playback_speed: number
  default_video_placement: 0 | 1  // 0=inbox, 1=queue
  hide_shorts: boolean
}

export interface PlayerState {
  videoId: string | null
  queueEntryId: string | null
  title: string
  thumbnailUrl: string | null
  isPlaying: boolean
  currentTime: number
  duration: number
  speed: number
}
