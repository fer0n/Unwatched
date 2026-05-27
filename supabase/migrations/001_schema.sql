-- Subscriptions
CREATE TABLE subscriptions (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title                  text NOT NULL DEFAULT '-',
  youtube_channel_id     text,
  youtube_playlist_id    text,
  feed_url               text NOT NULL,
  thumbnail_url          text,
  subscribed_date        timestamptz DEFAULT now(),
  most_recent_video_date timestamptz,
  is_archived            boolean NOT NULL DEFAULT false,
  created_at             timestamptz DEFAULT now()
);

CREATE INDEX idx_subs_user ON subscriptions(user_id) WHERE NOT is_archived;

ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "own" ON subscriptions USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Videos
CREATE TABLE videos (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  subscription_id uuid REFERENCES subscriptions(id) ON DELETE SET NULL,
  youtube_id      text NOT NULL,
  title           text NOT NULL DEFAULT '-',
  thumbnail_url   text,
  published_date  timestamptz,
  duration        numeric(10,3),
  elapsed_seconds numeric(10,3) NOT NULL DEFAULT 0,
  watched_date    timestamptz,
  is_yt_short     boolean NOT NULL DEFAULT false,
  created_at      timestamptz DEFAULT now(),
  UNIQUE(user_id, youtube_id)
);

CREATE INDEX idx_videos_user ON videos(user_id);
CREATE INDEX idx_videos_sub ON videos(subscription_id);

ALTER TABLE videos ENABLE ROW LEVEL SECURITY;
CREATE POLICY "own" ON videos USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Queue entries
CREATE TABLE queue_entries (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  video_id   uuid NOT NULL REFERENCES videos(id) ON DELETE CASCADE,
  sort_order integer NOT NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, video_id)
);

CREATE INDEX idx_queue_order ON queue_entries(user_id, sort_order);

ALTER TABLE queue_entries ENABLE ROW LEVEL SECURITY;
CREATE POLICY "own" ON queue_entries USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Inbox entries
CREATE TABLE inbox_entries (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  video_id   uuid NOT NULL REFERENCES videos(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, video_id)
);

CREATE INDEX idx_inbox_user ON inbox_entries(user_id, created_at DESC);

ALTER TABLE inbox_entries ENABLE ROW LEVEL SECURITY;
CREATE POLICY "own" ON inbox_entries USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- User settings
CREATE TABLE user_settings (
  user_id                 uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  default_playback_speed  numeric(4,2) NOT NULL DEFAULT 1.0,
  default_video_placement smallint NOT NULL DEFAULT 0,
  hide_shorts             boolean NOT NULL DEFAULT false,
  updated_at              timestamptz DEFAULT now()
);

ALTER TABLE user_settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "own" ON user_settings USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Auto-create user_settings row on signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.user_settings (user_id)
  VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Helper RPC: shift all queue entries down by 1 (for insert-at-top)
CREATE OR REPLACE FUNCTION queue_shift_down(p_user_id uuid)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
AS $$
  UPDATE queue_entries
  SET sort_order = sort_order + 1
  WHERE user_id = p_user_id;
$$;
