const AUTH_COOKIE = "dashboard_auth";
// How long a successful login stays valid without re-entering the password.
const AUTH_COOKIE_MAX_AGE = 60 * 60 * 24 * 30; // 30 days

// Non-reversible token derived from the password, safe to store in a cookie.
async function authToken(env) {
  const data = new TextEncoder().encode(`${env.DASHBOARD_PASSWORD}:unwatched-dashboard`);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

// Set-Cookie value that keeps the login alive across browser sessions.
export async function dashboardCookieHeader(env) {
  const token = await authToken(env);
  return `${AUTH_COOKIE}=${token}; Max-Age=${AUTH_COOKIE_MAX_AGE}; Path=/dashboard; HttpOnly; Secure; SameSite=Lax`;
}

export async function isDashboardAuthorized(request, env) {
  const expected = await authToken(env);
  const cookie = request.headers.get("Cookie") || "";
  if (cookie.split(/;\s*/).includes(`${AUTH_COOKIE}=${expected}`)) return true;

  const auth = request.headers.get("Authorization") || "";
  if (!auth.startsWith("Basic ")) return false;
  const decoded = atob(auth.slice(6));
  const password = decoded.split(":")[1] ?? "";
  return password === env.DASHBOARD_PASSWORD;
}

async function queryAnalytics(env, sql) {
  const res = await fetch(
    `https://api.cloudflare.com/client/v4/accounts/${env.CF_ACCOUNT_ID}/analytics_engine/sql`,
    {
      method: "POST",
      headers: { Authorization: `Bearer ${env.CF_API_TOKEN}` },
      body: sql,
    }
  );
  if (!res.ok) {
    throw new Error(`Analytics query failed: ${res.status} ${await res.text()}`);
  }
  return res.json();
}

// Boolean settings worth showing adoption for, mirrored from
// Const.settingsDefaults / Const.syncedSettingsDefaults (AppConstants.swift).
// Keep in sync manually when settings are added/removed there.
const BOOL_SETTINGS = [
  ["videoAddedToInboxNotification", false, "Notify: Inbox"],
  ["videoAddedToQueueNotification", false, "Notify: Queue"],
  ["showNotificationBadge", false, "Notification Badge"],
  ["autoClearNew", false, "Auto-clear \"New\""],
  ["refreshOnStartup", true, "Refresh on Startup"],
  ["requireClearConfirmation", true, "Require Clear Confirmation"],
  ["showAddToQueueButton", false, "Show Add-to-Queue Button"],
  ["showClearQueueButton", true, "Show Clear-Queue Button"],
  ["enableQueueContextMenu", false, "Queue Context Menu"],
  ["autoRefreshIgnoresSync", false, "Auto-refresh Ignores Sync"],
  ["useNoCookieUrl", false, "Use No-Cookie URL"],
  ["originalAudio", true, "Original Audio"],
  ["backgroundPlayback", true, "Background Playback"],
  ["hideMenuOnPlay", true, "Hide Menu on Play"],
  ["returnToQueue", false, "Return to Queue"],
  ["rotateOnPlay", false, "Rotate on Play"],
  ["playVideoFullscreen", false, "Play Fullscreen"],
  ["disableCaptions", false, "Disable Captions"],
  ["autoCaptionsOnSeekBack", false, "Auto-captions on Seek Back"],
  ["swipeGestureUp", true, "Swipe Gesture: Up"],
  ["swipeGestureDown", true, "Swipe Gesture: Down"],
  ["swipeGestureLeft", true, "Swipe Gesture: Left"],
  ["swipeGestureRight", true, "Swipe Gesture: Right"],
  ["autoAirplayHD", false, "Auto AirPlay HD"],
  ["playBrowserVideosInApp", false, "Play Browser Videos In-App"],
  ["surroundingEffect", true, "Surrounding Effect"],
  ["showTabBarLabels", true, "Show Tab Bar Labels"],
  ["showTabBarBadge", true, "Show Tab Bar Badge"],
  ["hidePlayerPageIndicator", false, "Hide Player Page Indicator"],
  ["lightAppIcon", false, "Light App Icon"],
  ["enableIcloudSync", false, "iCloud Sync"],
  ["automaticBackups", true, "Automatic Backups"],
  ["exludeWatchHistoryInBackup", false, "Exclude Watch History in Backup"],
  ["minimalBackups", true, "Minimal Backups"],
  ["autoDeleteBackups", false, "Auto-delete Backups"],
  ["hidePremium", false, "Hide Premium"],
  ["allowOnMatch", false, "Allow on Match"],
  ["mergeSponsorBlockChapters", false, "Merge SponsorBlock Chapters"],
  ["youtubePremium", false, "YouTube Premium"],
  ["skipSponsorSegments", false, "Skip Sponsor Segments"],
  // Presence-only flags for free-text settings — the values themselves are never sent
  // (see SetupView.sendSettings / getNonDefaultSettings).
  ["hasCustomApiKey", false, "Custom API Key Set"],
  ["hasSkipText", false, "Skip-Chapter Text Set"],
];

const SETTINGS_VALUE_PREFIX = "Unwatched.Setting.";
const COUNT_BUCKET_ORDER = ["0", "1-4", "5-9", "10-24", "25-49", "50-99", "100-499", "500-999", "1000+"];
const RAW_ROW_LIMIT = 20000;
const SNAPSHOT_WINDOW_DAYS = 30;
// Window for per-event engagement metrics (counts, per-user rates, funnels).
const TREND_WINDOW_DAYS = 7;
// Window for the capacity chart — enough history to spot a trend toward the free-plan cap.
const CAPACITY_WINDOW_DAYS = 30;
// Cloudflare Workers Free plan: 100k requests/day AND 100k Analytics Engine data points
// written/day. Requests are batched (<=25 events each), so writes/day is the larger of the
// two and the one to watch. Kept here so the server can hand it to the client chart.
const FREE_DAILY_LIMIT = 100000;

function parseParams(json) {
  try {
    return JSON.parse(json) ?? {};
  } catch {
    return {};
  }
}

// Keeps only the most recent row per userId (rows must be pre-sorted or we compare timestamps).
function latestPerUser(rows) {
  const byUser = new Map();
  for (const row of rows) {
    if (!row.userId || row.userId === "unknown") continue;
    const existing = byUser.get(row.userId);
    if (!existing || row.ts > existing.ts) {
      byUser.set(row.userId, row);
    }
  }
  return [...byUser.values()];
}

function tallySettings(latestSnapshots) {
  const totals = {};
  for (const [key, defaultValue, label] of BOOL_SETTINGS) {
    totals[key] = { label, default: defaultValue, on: 0, off: 0, notTouched: 0 };
  }
  for (const row of latestSnapshots) {
    const params = parseParams(row.params);
    for (const [key] of BOOL_SETTINGS) {
      if (!Object.prototype.hasOwnProperty.call(params, key)) {
        totals[key].notTouched++;
        continue;
      }
      const raw = String(params[key]).startsWith(SETTINGS_VALUE_PREFIX)
        ? params[key].slice(SETTINGS_VALUE_PREFIX.length)
        : params[key];
      const isOn = raw === "true" ? true : raw === "false" ? false : Number(raw) !== 0;
      if (isOn) totals[key].on++; else totals[key].off++;
    }
  }
  return totals;
}

function tallyBuckets(latestRows, paramKey) {
  const counts = Object.fromEntries(COUNT_BUCKET_ORDER.map((b) => [b, 0]));
  for (const row of latestRows) {
    const bucket = parseParams(row.params)[paramKey];
    if (bucket in counts) counts[bucket]++;
  }
  return counts;
}

// Mirrors Signal.bucket() (Signal.swift) for values logged as raw counts
// (e.g. SubscriptionCount) rather than pre-bucketed strings.
function bucketCount(value) {
  const n = Number(value);
  if (!Number.isFinite(n)) return null;
  if (n === 0) return "0";
  if (n <= 4) return "1-4";
  if (n <= 9) return "5-9";
  if (n <= 24) return "10-24";
  if (n <= 49) return "25-49";
  if (n <= 99) return "50-99";
  if (n <= 499) return "100-499";
  if (n <= 999) return "500-999";
  return "1000+";
}

function tallyRawBuckets(latestRows, paramKey) {
  const counts = Object.fromEntries(COUNT_BUCKET_ORDER.map((b) => [b, 0]));
  for (const row of latestRows) {
    const bucket = bucketCount(parseParams(row.params)[paramKey]);
    if (bucket && bucket in counts) counts[bucket]++;
  }
  return counts;
}

// Count distinct users per value of a free-form (but low-cardinality) param.
function tallyParam(rows, paramKey) {
  const counts = {};
  for (const row of rows) {
    const value = parseParams(row.params)[paramKey];
    if (value == null || value === "") continue;
    counts[value] = (counts[value] || 0) + 1;
  }
  return counts;
}

// Build channel (blob4) the row came from — see Signal.buildChannel (Signal.swift).
// Keeps local testing out of the live numbers without throwing it away: debug events
// still ingest and can be inspected by switching channel, they just don't count.
//
// `live` is an allowlist rather than "not debug" on purpose: anything unexpected — a
// channel added to the app before it's added here, or an "unknown" from a payload that
// didn't come from a real build — stays out of the live numbers until it's deliberately
// let in. The dataset was cut over to v3 when channels landed, so every row has one.
//
// SQL fragments, never the raw query value: `channelFilter` looks the requested channel
// up in this map and falls back to the default, so nothing user-supplied reaches the query.
const CHANNEL_FILTERS = {
  live: "blob4 IN ('release', 'testflight')",
  release: "blob4 = 'release'",
  testflight: "blob4 = 'testflight'",
  debug: "blob4 = 'debug'",
  all: "1 = 1",
};
export const DEFAULT_CHANNEL = "live";

function channelFilter(channel) {
  return CHANNEL_FILTERS[channel] ?? CHANNEL_FILTERS[DEFAULT_CHANNEL];
}

// Normalized back to the client so the UI can reflect what was actually queried
// rather than what it asked for.
function resolveChannel(channel) {
  return channel in CHANNEL_FILTERS ? channel : DEFAULT_CHANNEL;
}

// Last 50 events, newest first. Shared by the full dashboard payload and the
// lightweight /dashboard/recent refresh so the two never drift apart.
const recentEventsSql = (channel) =>
  `SELECT blob1 AS name, blob2 AS params, blob4 AS channel, double1 AS clientTimestamp FROM unwatched_analytics_v3 WHERE ${channelFilter(channel)} ORDER BY clientTimestamp DESC LIMIT 50`;

// Just the recent-events query, for the section's own refresh button — avoids
// re-running the ~13 queries handleDashboardData fans out.
export async function handleRecentData(env, channel) {
  try {
    const recent = await queryAnalytics(env, recentEventsSql(channel));
    return new Response(JSON.stringify({ recent: recent.data }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
}

export async function handleDashboardData(env, channel) {
  const ch = channelFilter(channel);
  try {
    const [
      counts,
      recent,
      uniqueUsers1d,
      uniqueUsers7d,
      uniqueUsers30d,
      dauTrend,
      eventTrend,
      writesTrend,
      settingsRaw,
      queueInboxRaw,
      subscriptionRaw,
      errorsRaw,
      errorTrend,
      paramEventsRaw,
    ] = await Promise.all([
      // Per-event totals AND distinct users over 7d — powers the engagement
      // table (per-active-user rates, adoption %), funnels, and comparisons.
      queryAnalytics(
        env,
        `SELECT blob1 AS name, count() AS count, count(DISTINCT blob3) AS users FROM unwatched_analytics_v3 WHERE ${ch} AND timestamp > NOW() - INTERVAL '${TREND_WINDOW_DAYS}' DAY AND blob3 != 'unknown' GROUP BY name ORDER BY count DESC LIMIT 200`
      ),
      queryAnalytics(env, recentEventsSql(channel)),
      queryAnalytics(
        env,
        `SELECT count(DISTINCT blob3) AS uniqueUsers FROM unwatched_analytics_v3 WHERE ${ch} AND timestamp > NOW() - INTERVAL '1' DAY AND blob3 != 'unknown'`
      ),
      queryAnalytics(
        env,
        `SELECT count(DISTINCT blob3) AS uniqueUsers FROM unwatched_analytics_v3 WHERE ${ch} AND timestamp > NOW() - INTERVAL '7' DAY AND blob3 != 'unknown'`
      ),
      queryAnalytics(
        env,
        `SELECT count(DISTINCT blob3) AS uniqueUsers FROM unwatched_analytics_v3 WHERE ${ch} AND timestamp > NOW() - INTERVAL '30' DAY AND blob3 != 'unknown'`
      ),
      // Daily active users over the trend window (one point per day).
      queryAnalytics(
        env,
        `SELECT toStartOfDay(timestamp) AS day, count(DISTINCT blob3) AS users FROM unwatched_analytics_v3 WHERE ${ch} AND timestamp > NOW() - INTERVAL '${TREND_WINDOW_DAYS}' DAY AND blob3 != 'unknown' GROUP BY day ORDER BY day`
      ),
      // Total event volume per day over the trend window.
      queryAnalytics(
        env,
        `SELECT toStartOfDay(timestamp) AS day, count() AS events FROM unwatched_analytics_v3 WHERE ${ch} AND timestamp > NOW() - INTERVAL '${TREND_WINDOW_DAYS}' DAY GROUP BY day ORDER BY day`
      ),
      // Data points written per day over a longer window — one row = one writeDataPoint
      // call = one event, which is exactly the Analytics Engine "data points written"
      // billing metric. Since a request batches up to 25 events, writes/day is an upper
      // bound on requests/day, so one line answers both free-plan caps (see FREE_DAILY_LIMIT).
      // Deliberately NOT channel-filtered: debug and TestFlight writes bill the same as
      // release ones, so the capacity chart has to show every row actually written.
      queryAnalytics(
        env,
        `SELECT toStartOfDay(timestamp) AS day, count() AS writes FROM unwatched_analytics_v3 WHERE timestamp > NOW() - INTERVAL '${CAPACITY_WINDOW_DAYS}' DAY GROUP BY day ORDER BY day`
      ),
      queryAnalytics(
        env,
        `SELECT blob2 AS params, blob3 AS userId, double1 AS ts FROM unwatched_analytics_v3 WHERE ${ch} AND blob1 = 'SettingsSnapshot' AND timestamp > NOW() - INTERVAL '${SNAPSHOT_WINDOW_DAYS}' DAY LIMIT ${RAW_ROW_LIMIT}`
      ),
      queryAnalytics(
        env,
        `SELECT blob1 AS name, blob2 AS params, blob3 AS userId, double1 AS ts FROM unwatched_analytics_v3 WHERE ${ch} AND blob1 IN ('Queue.Count', 'Inbox.Count') AND timestamp > NOW() - INTERVAL '${SNAPSHOT_WINDOW_DAYS}' DAY LIMIT ${RAW_ROW_LIMIT}`
      ),
      queryAnalytics(
        env,
        `SELECT blob2 AS params, blob3 AS userId, double1 AS ts FROM unwatched_analytics_v3 WHERE ${ch} AND blob1 = 'SubscriptionCount' AND timestamp > NOW() - INTERVAL '${SNAPSHOT_WINDOW_DAYS}' DAY LIMIT ${RAW_ROW_LIMIT}`
      ),
      queryAnalytics(
        env,
        `SELECT blob2 AS params, count() AS count FROM unwatched_analytics_v3 WHERE ${ch} AND blob1 = 'Error' AND timestamp > NOW() - INTERVAL '${SNAPSHOT_WINDOW_DAYS}' DAY GROUP BY params ORDER BY count DESC LIMIT 50`
      ),
      queryAnalytics(
        env,
        `SELECT toStartOfDay(timestamp) AS day, count() AS count FROM unwatched_analytics_v3 WHERE ${ch} AND blob1 = 'Error' AND timestamp > NOW() - INTERVAL '${SNAPSHOT_WINDOW_DAYS}' DAY GROUP BY day ORDER BY day`
      ),
      // Consolidated param-carrying events, grouped by their raw params JSON so the
      // client can break them out by dimension (Video.Action by action/context, etc).
      queryAnalytics(
        env,
        `SELECT blob1 AS name, blob2 AS params, count() AS count FROM unwatched_analytics_v3 WHERE ${ch} AND blob1 IN ('Video.Action', 'Player.MoreMenu', 'Search.Submitted', 'Player.Start') AND timestamp > NOW() - INTERVAL '${TREND_WINDOW_DAYS}' DAY GROUP BY name, params ORDER BY count DESC LIMIT 500`
      ),
    ]);

    // Every row here has one userId per app instance, never anything identifying
    // (see AnalyticsEvent.anonymousUserId) — de-duped down to one snapshot per user.
    const latestSettings = latestPerUser(settingsRaw.data);
    const queueInboxRows = queueInboxRaw.data;
    const latestQueue = latestPerUser(queueInboxRows.filter((r) => r.name === "Queue.Count"));
    const latestInbox = latestPerUser(queueInboxRows.filter((r) => r.name === "Inbox.Count"));
    const latestSubs = latestPerUser(subscriptionRaw.data);

    const activeUsers = {
      daily: uniqueUsers1d.data[0]?.uniqueUsers ?? 0,
      weekly: uniqueUsers7d.data[0]?.uniqueUsers ?? 0,
      monthly: uniqueUsers30d.data[0]?.uniqueUsers ?? 0,
    };

    return new Response(
      JSON.stringify({
        // Echoed back normalized so the picker shows what was actually queried
        // (an unknown value silently falls back to DEFAULT_CHANNEL).
        channel: resolveChannel(channel),
        // count/users are per-event over TREND_WINDOW_DAYS; the client derives
        // per-active-user rates and adoption % against activeUsers.
        counts: counts.data,
        trendWindowDays: TREND_WINDOW_DAYS,
        recent: recent.data,
        activeUsers,
        activeUsersTrend: dauTrend.data,
        eventTrend: eventTrend.data,
        writes: {
          windowDays: CAPACITY_WINDOW_DAYS,
          freeDailyLimit: FREE_DAILY_LIMIT,
          trend: writesTrend.data,
        },
        settings: {
          sampleSize: latestSettings.length,
          windowDays: SNAPSHOT_WINDOW_DAYS,
          totals: tallySettings(latestSettings),
        },
        // Device family + OS version per user, carried on the settings snapshot.
        platform: {
          windowDays: SNAPSHOT_WINDOW_DAYS,
          sampleSize: latestSettings.length,
          devices: tallyParam(latestSettings, "device"),
          os: tallyParam(latestSettings, "os"),
        },
        queueInbox: {
          windowDays: SNAPSHOT_WINDOW_DAYS,
          queue: { sampleSize: latestQueue.length, buckets: tallyBuckets(latestQueue, "Queue.Count.Value") },
          inbox: { sampleSize: latestInbox.length, buckets: tallyBuckets(latestInbox, "Inbox.Count.Value") },
        },
        subscriptions: {
          windowDays: SNAPSHOT_WINDOW_DAYS,
          sampleSize: latestSubs.length,
          buckets: tallyRawBuckets(latestSubs, "SubscriptionCount.Value"),
        },
        errors: {
          windowDays: SNAPSHOT_WINDOW_DAYS,
          top: errorsRaw.data.map((r) => ({ id: parseParams(r.params).id ?? "unknown", count: Number(r.count) })),
          trend: errorTrend.data,
        },
        // [{ name, params: {...}, count }] for the consolidated events.
        paramEvents: paramEventsRaw.data.map((r) => ({
          name: r.name,
          params: parseParams(r.params),
          count: Number(r.count),
        })),
      }),
      { headers: { "Content-Type": "application/json" } }
    );
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
}

export const DASHBOARD_HTML = `<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1" />
<title>Unwatched Analytics</title>
<style>
  * { box-sizing: border-box; }
  body {
    font-family: -apple-system, sans-serif;
    margin: 0;
    padding: 1rem;
    background: #111;
    color: #eee;
    -webkit-text-size-adjust: 100%;
  }
  /* While loading, shimmer the real content containers in place so the skeleton
     matches the true page layout: headings stay put and each section shows a
     placeholder block where its content will render. */
  @keyframes sk-shimmer { 0% { background-position: 200% 0; } 100% { background-position: -200% 0; } }
  body.loading .stat-cards,
  body.loading .card,
  body.loading .pie-chart,
  body.loading .table-scroll,
  body.loading .settings-grid,
  body.loading #funnels,
  body.loading #compare,
  body.loading #breakdowns {
    background: linear-gradient(90deg, #1b1b1b 25%, #262626 37%, #1b1b1b 63%);
    background-size: 200% 100%;
    animation: sk-shimmer 1.4s ease-in-out infinite;
    border-color: transparent;
    border-radius: 10px;
  }
  body.loading .stat-cards { min-height: 4.5rem; }
  body.loading .card { min-height: 8rem; }
  body.loading .pie-chart { min-height: 9rem; }
  body.loading .table-scroll { min-height: 8rem; }
  body.loading .settings-grid { min-height: 10rem; }
  body.loading #funnels,
  body.loading #compare,
  body.loading #breakdowns { min-height: 8rem; }
  /* Hide the real (empty) table markup so only the shimmer shows. */
  body.loading .table-scroll table { visibility: hidden; }
  @media (prefers-reduced-motion: reduce) {
    body.loading .stat-cards, body.loading .card, body.loading .pie-chart,
    body.loading .table-scroll, body.loading .settings-grid,
    body.loading #funnels, body.loading #compare, body.loading #breakdowns { animation: none; }
  }
  h1 { font-size: 1.2rem; margin: 0; }
  .page-head { display: flex; align-items: center; gap: 0.75rem; flex-wrap: wrap; margin: 0 0 0.5rem; }
  .channel-select {
    background: #1b1b1b; border: 1px solid #2a2a2a; border-radius: 8px;
    color: #ccc; font-size: 0.78rem; padding: 0.3rem 0.5rem; cursor: pointer;
  }
  /* Anything other than the default view is loud on purpose: debug/TestFlight-only
     numbers look exactly like real ones, so the picker has to be hard to overlook. */
  .channel-select.alt { border-color: #fbbf24; color: #fbbf24; }
  .channel-note { font-size: 0.75rem; color: #fbbf24; margin: 0 0 0.5rem; }
  h2 { font-size: 0.95rem; color: #aaa; margin: 1.5rem 0 0.5rem; }
  h2.section-head { display: flex; align-items: center; gap: 0.5rem; }
  .refresh-btn {
    background: #1b1b1b; border: 1px solid #2a2a2a; border-radius: 6px;
    color: #ccc; cursor: pointer; font-size: 0.9rem; line-height: 1; padding: 0.2rem 0.45rem;
  }
  .refresh-btn:hover { background: #242424; }
  .refresh-btn:disabled { opacity: 0.5; cursor: default; }
  .refresh-icon { display: inline-block; }
  @keyframes spin { to { transform: rotate(360deg); } }
  .refresh-btn.spinning .refresh-icon { animation: spin 0.7s linear infinite; }
  @media (prefers-reduced-motion: reduce) { .refresh-btn.spinning .refresh-icon { animation: none; } }
  .hint { font-size: 0.75rem; color: #777; margin: -0.25rem 0 0.75rem; }
  .table-scroll { overflow-x: auto; -webkit-overflow-scrolling: touch; margin: 0 -1rem; padding: 0 1rem; }
  table { border-collapse: collapse; width: 100%; min-width: 320px; }
  th, td { text-align: left; padding: 0.5rem 0.6rem; border-bottom: 1px solid #333; font-size: 0.85rem; }
  td { word-break: break-word; }
  td:nth-child(2) { max-width: 45vw; }
  th { color: #888; font-weight: 500; white-space: nowrap; }
  #error { color: #f66; font-size: 0.85rem; }

  .stat-cards { display: grid; grid-template-columns: repeat(3, 1fr); gap: 0.6rem; }
  .stat-card { background: #1b1b1b; border: 1px solid #2a2a2a; border-radius: 10px; padding: 0.75rem; text-align: center; }
  .stat-card .value { font-size: 1.4rem; font-weight: 600; }
  .stat-card .label { font-size: 0.7rem; color: #888; margin-top: 0.15rem; }

  .settings-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(140px, 1fr)); gap: 0.75rem; }
  .setting-card { background: #1b1b1b; border: 1px solid #2a2a2a; border-radius: 10px; padding: 0.6rem; text-align: center; }
  .setting-card .setting-label { font-size: 0.72rem; color: #ccc; margin-bottom: 0.4rem; min-height: 2.2em; }
  .legend { font-size: 0.68rem; margin-top: 0.4rem; text-align: left; }
  .legend div { display: flex; align-items: center; gap: 0.35rem; white-space: nowrap; }
  .swatch { width: 8px; height: 8px; border-radius: 2px; flex: none; }

  .settings-grid .setting-card.hidden { display: none; }
  #recent tr.hidden { display: none; }
  .toggle-btn {
    display: block; margin: 0.75rem auto 0; padding: 0.45rem 1rem;
    background: #1b1b1b; border: 1px solid #2a2a2a; border-radius: 8px;
    color: #ccc; font-size: 0.78rem; cursor: pointer;
  }
  .toggle-btn:hover { background: #242424; }

  .pie-chart { display: flex; align-items: center; gap: 1.25rem; flex-wrap: wrap; background: #1b1b1b; border: 1px solid #2a2a2a; border-radius: 10px; padding: 1rem; }
  .pie-chart svg { flex: none; }
  .pie-legend { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 0.25rem 1rem; font-size: 0.75rem; flex: 1 1 160px; min-width: 0; }
  .pie-legend div { display: flex; align-items: center; gap: 0.4rem; min-width: 0; }
  .pie-legend div span:last-child, .pie-legend div { overflow: hidden; text-overflow: ellipsis; }
  .pie-legend .muted { color: #777; }

  .card { background: #1b1b1b; border: 1px solid #2a2a2a; border-radius: 10px; padding: 1rem; }
  .card svg { display: block; width: 100%; height: auto; }
  .chart-meta { display: flex; justify-content: space-between; font-size: 0.72rem; color: #888; margin-bottom: 0.5rem; }
  .chart-meta b { color: #eee; font-weight: 600; }

  .grid-2 { display: grid; grid-template-columns: minmax(0, 1fr); gap: 0.75rem; }
  .grid-2 > * { min-width: 0; }
  @media (min-width: 720px) { .grid-2 { grid-template-columns: repeat(2, minmax(0, 1fr)); } }

  td.num { text-align: right; font-variant-numeric: tabular-nums; white-space: nowrap; }
  th.num { text-align: right; }
  .rate-bar { position: relative; }
  .rate-bar span { position: absolute; left: 0; top: 0; bottom: 0; background: rgba(59,130,246,0.25); border-radius: 3px; }
  .rate-bar b { position: relative; font-weight: 600; }

  .cmp-chart { display: flex; flex-direction: column; gap: 0.5rem; }
  .cmp-row { display: grid; grid-template-columns: 9rem 1fr 3.5rem; align-items: center; gap: 0.5rem; font-size: 0.78rem; }
  .cmp-label { color: #ccc; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .cmp-track { background: #222; border-radius: 4px; overflow: hidden; height: 12px; }
  .cmp-fill { display: block; height: 100%; border-radius: 4px; }
  .cmp-count { text-align: right; color: #999; font-variant-numeric: tabular-nums; }

  .funnel { display: flex; flex-direction: column; gap: 0.1rem; }
  .funnel-row { position: relative; display: flex; align-items: center; height: 32px; border: 1px solid #2a2a2a; border-radius: 6px; overflow: hidden; }
  .funnel-row .fill { position: absolute; left: 0; top: 0; bottom: 0; background: linear-gradient(90deg, #1e3a8a, #3b82f6); }
  .funnel-row .txt { position: relative; padding: 0 0.55rem; font-size: 0.75rem; color: #fff; white-space: nowrap; }
  .funnel-conv { font-size: 0.68rem; color: #888; margin: 0.15rem 0 0.45rem 0.2rem; }

  @media (min-width: 640px) {
    body { padding: 2rem; }
    h1 { font-size: 1.4rem; }
    h2 { font-size: 1rem; }
    .table-scroll { margin: 0; padding: 0; }
  }
  @media (max-width: 420px) {
    .stat-cards { grid-template-columns: repeat(3, 1fr); gap: 0.4rem; }
    .stat-card .value { font-size: 1.1rem; }
  }
</style>
</head>
<body class="loading">
<div class="page-head">
  <h1>Unwatched Analytics</h1>
  <select id="channel" class="channel-select" aria-label="Build channel"></select>
</div>
<div class="channel-note" id="channelNote" hidden></div>
<div id="error"></div>

<h2>Active users (anonymous, on-device id only)</h2>
<div class="stat-cards" id="activeUsers"></div>

<h2>Active users per day (30d)</h2>
<div class="card" id="dauTrend"></div>

<h2>Event volume per day (30d)</h2>
<div class="card" id="eventTrend"></div>

<h2>Free-plan capacity (30d)</h2>
<p class="hint" id="writesHint"></p>
<div class="card" id="writesTrend"></div>

<h2 class="section-head">Recent events <button id="recentRefresh" class="refresh-btn" title="Refresh recent events" aria-label="Refresh recent events"><span class="refresh-icon">↻</span></button></h2>
<div class="table-scroll">
<table id="recent"><thead><tr><th>Event</th><th>Params</th><th>Channel</th><th>When</th></tr></thead><tbody></tbody></table>
</div>
<button id="recentToggle" class="toggle-btn" hidden></button>

<h2>Devices &amp; OS</h2>
<div class="hint" id="platformHint"></div>
<div class="grid-2">
  <div>
    <div class="chart-meta"><span><b>Device</b></span></div>
    <div class="pie-chart" id="devicePie"></div>
  </div>
  <div>
    <div class="chart-meta"><span><b>OS version</b></span></div>
    <div class="pie-chart" id="osPie"></div>
  </div>
</div>

<h2>Engagement <span id="engagementWindow"></span></h2>
<div class="hint">Per-user = events ÷ weekly active users. Adoption = share of weekly active users who did it at least once.</div>
<div class="table-scroll">
<table id="engagement"><thead><tr>
  <th>Event</th><th class="num">Count</th><th class="num">Users</th><th class="num">Per user</th><th class="num">Adoption</th>
</tr></thead><tbody></tbody></table>
</div>

<h2>Funnels</h2>
<div class="hint" id="funnelHint"></div>
<div class="grid-2" id="funnels"></div>

<h2>Feature comparison</h2>
<div class="hint" id="compareHint"></div>
<div class="grid-2" id="compare"></div>

<h2>How playback starts <span id="playbackStartWindow"></span></h2>
<div class="pie-chart" id="playbackStartPie"></div>

<h2>Action breakdowns</h2>
<div class="hint" id="breakdownHint"></div>
<div class="grid-2" id="breakdowns"></div>

<h2>Settings adoption</h2>
<div class="hint" id="settingsHint"></div>
<div class="settings-grid" id="settingsGrid"></div>
<button id="settingsToggle" class="toggle-btn" hidden></button>

<div class="grid-2">
  <div>
    <h2>Queue size</h2>
    <div class="hint" id="queueHint"></div>
    <div class="pie-chart" id="queuePie"></div>
  </div>
  <div>
    <h2>Inbox size</h2>
    <div class="hint" id="inboxHint"></div>
    <div class="pie-chart" id="inboxPie"></div>
  </div>
</div>

<h2>Subscription count</h2>
<div class="hint" id="subsHint"></div>
<div class="pie-chart" id="subsPie"></div>

<h2>Errors <span id="errorWindow"></span></h2>
<div class="card" id="errorTrend"></div>
<div class="table-scroll" style="margin-top:0.75rem">
<table id="errors"><thead><tr><th>Error id</th><th class="num">Count</th></tr></thead><tbody></tbody></table>
</div>

<script>
const COLORS = { on: '#4ade80', off: '#fb923c', notTouched: '#555' };
// Ordered small -> large so bucket ranges read as a cool-to-warm gradient.
const BUCKET_COLORS = ['#1e3a8a', '#2563eb', '#3b82f6', '#60a5fa', '#38bdf8', '#22d3ee', '#34d399', '#a3e635', '#facc15'];
const SETTINGS_COLLAPSED_COUNT = 8;
const RECENT_COLLAPSED_COUNT = 5;

// Build channel to report on. Kept in the URL rather than in memory so the choice
// survives a reload, can be bookmarked, and — since the page renders once from a
// single payload — switching can just reload instead of re-rendering in place.
const CHANNEL_OPTIONS = [
  ['live', 'Live (release + TestFlight)'],
  ['release', 'Release only'],
  ['testflight', 'TestFlight only'],
  ['debug', 'Debug only'],
  ['all', 'All channels'],
];
const DEFAULT_CHANNEL = 'live';
const CHANNEL_NOTES = {
  release: 'Release builds only — TestFlight beta activity is excluded.',
  testflight: 'TestFlight builds only — this is beta activity, not your live numbers.',
  debug: 'Debug builds only — this is your own local testing, not real usage.',
  all: 'All channels, including your own debug builds — not your live numbers.',
};
const currentChannel = new URLSearchParams(location.search).get('channel') || DEFAULT_CHANNEL;
const channelQuery = '?channel=' + encodeURIComponent(currentChannel);

const channelSelect = document.getElementById('channel');
for (const [value, label] of CHANNEL_OPTIONS) {
  const option = document.createElement('option');
  option.value = value;
  option.textContent = label;
  channelSelect.appendChild(option);
}
channelSelect.value = CHANNEL_OPTIONS.some(([v]) => v === currentChannel) ? currentChannel : DEFAULT_CHANNEL;
channelSelect.classList.toggle('alt', channelSelect.value !== DEFAULT_CHANNEL);
channelSelect.onchange = () => {
  // Drop the saved scroll position: a different channel is a different page of numbers.
  sessionStorage.removeItem('dashboardScroll');
  location.search = '?channel=' + encodeURIComponent(channelSelect.value);
};
const channelNote = document.getElementById('channelNote');
if (CHANNEL_NOTES[channelSelect.value]) {
  channelNote.textContent = CHANNEL_NOTES[channelSelect.value];
  channelNote.hidden = false;
}

function donutSVG(on, off, notTouched, size) {
  size = size || 64;
  const total = on + off + notTouched;
  const r = size / 2 - 6;
  const c = size / 2;
  const circumference = 2 * Math.PI * r;
  if (total === 0) {
    return '<svg width="' + size + '" height="' + size + '" viewBox="0 0 ' + size + ' ' + size + '">' +
      '<circle cx="' + c + '" cy="' + c + '" r="' + r + '" fill="none" stroke="#333" stroke-width="10"/></svg>';
  }
  const segments = [
    { value: on, color: COLORS.on },
    { value: off, color: COLORS.off },
    { value: notTouched, color: COLORS.notTouched },
  ];
  let offset = 0;
  let circles = '';
  for (const seg of segments) {
    if (seg.value === 0) continue;
    const frac = seg.value / total;
    const dash = frac * circumference;
    circles += '<circle cx="' + c + '" cy="' + c + '" r="' + r + '" fill="none" stroke="' + seg.color + '" stroke-width="10" ' +
      'stroke-dasharray="' + dash + ' ' + (circumference - dash) + '" stroke-dashoffset="' + (-offset) + '" ' +
      'transform="rotate(-90 ' + c + ' ' + c + ')"/>';
    offset += dash;
  }
  return '<svg width="' + size + '" height="' + size + '" viewBox="0 0 ' + size + ' ' + size + '">' + circles + '</svg>';
}

// Filled donut showing how a set of segments ({value,color}) compare as shares.
function pieSVG(segments, size) {
  size = size || 132;
  const total = segments.reduce((sum, s) => sum + s.value, 0);
  const r = size / 4;
  const c = size / 2;
  const strokeWidth = size / 2;
  const circumference = 2 * Math.PI * r;
  if (total === 0) {
    return '<svg width="' + size + '" height="' + size + '" viewBox="0 0 ' + size + ' ' + size + '">' +
      '<circle cx="' + c + '" cy="' + c + '" r="' + r + '" fill="none" stroke="#333" stroke-width="' + strokeWidth + '"/></svg>';
  }
  let offset = 0;
  let circles = '';
  for (const seg of segments) {
    if (seg.value === 0) continue;
    const frac = seg.value / total;
    const dash = frac * circumference;
    circles += '<circle cx="' + c + '" cy="' + c + '" r="' + r + '" fill="none" stroke="' + seg.color + '" stroke-width="' + strokeWidth + '" ' +
      'stroke-dasharray="' + dash + ' ' + (circumference - dash) + '" stroke-dashoffset="' + (-offset) + '" ' +
      'transform="rotate(-90 ' + c + ' ' + c + ')"/>';
    offset += dash;
  }
  return '<svg width="' + size + '" height="' + size + '" viewBox="0 0 ' + size + ' ' + size + '">' + circles + '</svg>';
}

function timeAgo(ts) {
  const sec = Math.max(0, Math.floor((Date.now() - ts) / 1000));
  if (sec < 5) return 'just now';
  if (sec < 60) return sec + 's ago';
  const min = Math.floor(sec / 60);
  if (min < 60) return min + 'm ago';
  const hr = Math.floor(min / 60);
  if (hr < 24) return hr + 'h ago';
  const day = Math.floor(hr / 24);
  if (day < 30) return day + 'd ago';
  return Math.floor(day / 30) + 'mo ago';
}

function legendRow(color, text) {
  return '<div><span class="swatch" style="background:' + color + '"></span>' + text + '</div>';
}

function renderSettingsGrid(el, toggleBtn, settings) {
  const totals = settings.totals;
  el.innerHTML = '';
  const cards = [];
  let index = 0;
  for (const key in totals) {
    const s = totals[key];
    const total = s.on + s.off + s.notTouched;
    const pct = (n) => (total ? Math.round((n / total) * 100) : 0);
    const card = document.createElement('div');
    card.className = 'setting-card';
    if (index >= SETTINGS_COLLAPSED_COUNT) card.classList.add('hidden');
    card.innerHTML =
      '<div class="setting-label">' + s.label + '</div>' +
      donutSVG(s.on, s.off, s.notTouched) +
      '<div class="legend">' +
        legendRow(COLORS.on, 'On ' + s.on + ' (' + pct(s.on) + '%)') +
        legendRow(COLORS.off, 'Off ' + s.off + ' (' + pct(s.off) + '%)') +
        legendRow(COLORS.notTouched, 'Untouched ' + s.notTouched + ' (' + pct(s.notTouched) + '%)') +
      '</div>';
    el.appendChild(card);
    cards.push(card);
    index++;
  }

  const hiddenCount = cards.length - SETTINGS_COLLAPSED_COUNT;
  if (hiddenCount <= 0) {
    toggleBtn.hidden = true;
    return;
  }
  let expanded = false;
  const sync = () => {
    cards.forEach((card, i) => card.classList.toggle('hidden', !expanded && i >= SETTINGS_COLLAPSED_COUNT));
    toggleBtn.textContent = expanded ? 'Show fewer' : 'Show all ' + cards.length + ' settings';
  };
  toggleBtn.hidden = false;
  toggleBtn.onclick = () => { expanded = !expanded; sync(); };
  sync();
}

function renderPie(el, buckets) {
  el.innerHTML = '';
  const entries = Object.entries(buckets);
  const total = entries.reduce((sum, [, count]) => sum + count, 0);
  const segments = entries.map(([, count], i) => ({ value: count, color: BUCKET_COLORS[i % BUCKET_COLORS.length] }));

  const legend = entries.map(([bucket, count], i) => {
    const pct = total ? Math.round((count / total) * 100) : 0;
    const cls = count === 0 ? ' class="muted"' : '';
    return '<div' + cls + '><span class="swatch" style="background:' + BUCKET_COLORS[i % BUCKET_COLORS.length] +
      '"></span>' + bucket + ': ' + count + ' (' + pct + '%)</div>';
  }).join('');

  el.innerHTML = pieSVG(segments) + '<div class="pie-legend">' + legend + '</div>';
}

// Distinct base hues per platform+major so e.g. all "iOS 26.x" read as one colour
// family and "iOS 18.x" as another — easy to eyeball major versions at a glance.
const OS_HUES = [210, 28, 145, 275, 0, 190, 50, 320];

function renderOsPie(el, osCounts) {
  const parsed = Object.entries(osCounts).map(function (e) {
    const m = String(e[0]).match(/^(.*?)\s*(\d+)(?:\.(\d+))?/);
    return {
      label: e[0], count: e[1],
      platform: m ? m[1].trim() : e[0],
      major: m ? parseInt(m[2], 10) : 0,
      minor: m && m[3] ? parseInt(m[3], 10) : 0,
    };
  });
  parsed.forEach(function (p) { p.key = p.platform + ' ' + p.major; });
  // Newest first within a family, families grouped together.
  parsed.sort(function (a, b) {
    return a.platform.localeCompare(b.platform) || b.major - a.major || b.minor - a.minor;
  });

  const hueByKey = {};
  const minorsByKey = {};
  parsed.forEach(function (p) {
    if (!(p.key in hueByKey)) hueByKey[p.key] = OS_HUES[Object.keys(hueByKey).length % OS_HUES.length];
    if (!minorsByKey[p.key]) minorsByKey[p.key] = [];
    if (minorsByKey[p.key].indexOf(p.minor) === -1) minorsByKey[p.key].push(p.minor);
  });
  const colorFor = function (p) {
    const idx = minorsByKey[p.key].indexOf(p.minor);
    return 'hsl(' + hueByKey[p.key] + ', 62%, ' + (44 + (idx % 5) * 9) + '%)';
  };

  const total = parsed.reduce(function (s, p) { return s + p.count; }, 0);
  const segments = parsed.map(function (p) { return { value: p.count, color: colorFor(p) }; });
  const legend = parsed.map(function (p) {
    const pct = total ? Math.round(p.count / total * 100) : 0;
    return '<div><span class="swatch" style="background:' + colorFor(p) + '"></span>' + p.label + ': ' + p.count + ' (' + pct + '%)</div>';
  }).join('');
  el.innerHTML = pieSVG(segments) + '<div class="pie-legend">' + (legend || '<div class="muted">No data yet.</div>') + '</div>';
}

function fmtNum(n) {
  n = Number(n) || 0;
  if (n >= 1000000) return (n / 1000000).toFixed(1) + 'M';
  if (n >= 1000) return (n / 1000).toFixed(n >= 10000 ? 0 : 1) + 'k';
  return String(Math.round(n));
}

function dayLabel(day) {
  const d = new Date(String(day).replace(' ', 'T'));
  if (isNaN(d.getTime())) return String(day).slice(5, 10);
  return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
}

// Line + area chart from a series of {day, [valueKey]}.
function lineChartSVG(series, valueKey, color, limit) {
  const W = 640, H = 180, padL = 34, padR = 12, padT = 12, padB = 22;
  const pts = series.map(function (row) { return { label: row.day, value: Number(row[valueKey]) || 0 }; });
  if (pts.length === 0) return '<div class="hint">No data yet.</div>';
  const values = pts.map(function (p) { return p.value; });
  // With a limit line, keep the ceiling on the axis so the headroom to the cap is visible
  // even when daily volume sits far below it.
  const max = Math.max(1, Math.max.apply(null, values), limit || 0);
  const innerW = W - padL - padR, innerH = H - padT - padB;
  const x = function (i) { return padL + (pts.length === 1 ? innerW / 2 : innerW * i / (pts.length - 1)); };
  const y = function (v) { return padT + innerH * (1 - v / max); };
  let line = '';
  pts.forEach(function (p, i) { line += (i === 0 ? 'M' : 'L') + x(i).toFixed(1) + ' ' + y(p.value).toFixed(1) + ' '; });
  const area = 'M' + x(0).toFixed(1) + ' ' + y(0).toFixed(1) + ' ' + line.replace(/^M/, 'L') +
    'L' + x(pts.length - 1).toFixed(1) + ' ' + y(0).toFixed(1) + ' Z';
  let grid = '';
  [0, max / 2, max].forEach(function (v) {
    const gy = y(v);
    grid += '<line x1="' + padL + '" y1="' + gy.toFixed(1) + '" x2="' + (W - padR) + '" y2="' + gy.toFixed(1) + '" stroke="#2a2a2a"/>' +
      '<text x="' + (padL - 4) + '" y="' + (gy + 3).toFixed(1) + '" text-anchor="end" font-size="9" fill="#777">' + fmtNum(v) + '</text>';
  });
  let xlabels = '';
  const idxs = pts.length === 1 ? [0] : [0, Math.floor((pts.length - 1) / 2), pts.length - 1];
  idxs.forEach(function (i, k) {
    const anchor = k === 0 ? 'start' : (k === idxs.length - 1 ? 'end' : 'middle');
    xlabels += '<text x="' + x(i).toFixed(1) + '" y="' + (H - 6) + '" text-anchor="' + anchor + '" font-size="9" fill="#777">' + dayLabel(pts[i].label) + '</text>';
  });
  const lastI = pts.length - 1;
  const dot = '<circle cx="' + x(lastI).toFixed(1) + '" cy="' + y(pts[lastI].value).toFixed(1) + '" r="3" fill="' + color + '"/>';
  let limitLine = '';
  if (limit) {
    const ly = y(limit);
    limitLine = '<line x1="' + padL + '" y1="' + ly.toFixed(1) + '" x2="' + (W - padR) + '" y2="' + ly.toFixed(1) +
      '" stroke="#f87171" stroke-width="1" stroke-dasharray="4 3"/>' +
      '<text x="' + (W - padR) + '" y="' + (ly - 4).toFixed(1) + '" text-anchor="end" font-size="9" fill="#f87171">free limit ' + fmtNum(limit) + '/day</text>';
  }
  return '<svg viewBox="0 0 ' + W + ' ' + H + '" xmlns="http://www.w3.org/2000/svg">' +
    grid +
    '<path d="' + area + '" fill="' + color + '" fill-opacity="0.15"/>' +
    '<path d="' + line + '" fill="none" stroke="' + color + '" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"/>' +
    limitLine + dot + xlabels + '</svg>';
}

function renderLineChart(el, series, valueKey, color, limit) {
  series = series || [];
  const values = series.map(function (r) { return Number(r[valueKey]) || 0; });
  const total = values.reduce(function (a, b) { return a + b; }, 0);
  const avg = values.length ? total / values.length : 0;
  const peak = values.length ? Math.max.apply(null, values) : 0;
  // With a limit, the useful right-hand stat is how close the busiest day came to the cap.
  const right = limit
    ? 'peak <b>' + fmtNum(peak) + '</b> · <b>' + Math.round(peak / limit * 100) + '%</b> of limit'
    : 'peak <b>' + fmtNum(peak) + '</b>';
  el.innerHTML = '<div class="chart-meta"><span>avg <b>' + fmtNum(avg) + '</b>/day</span><span>' + right + '</span></div>' +
    lineChartSVG(series, valueKey, color, limit);
}

const FUNNELS = [
  { title: 'Premium conversion', steps: [
    ['Premium.ShowPopup', 'Saw premium popup'],
    ['Premium.LearnMore', 'Tapped learn more'],
    ['Premium.Subscribe', 'Subscribed'],
  ]},
  { title: 'New user activation', steps: [
    ['Onboarding.BrowseYoutube', 'Browsed YouTube'],
    ['Browser.AddSubscription', 'Added a subscription'],
    ['Player.WatchedVideo', 'Watched a video'],
  ]},
];

function renderFunnels(el, usersByEvent) {
  el.innerHTML = '';
  FUNNELS.forEach(function (f) {
    const counts = f.steps.map(function (s) { return usersByEvent[s[0]] || 0; });
    const top = Math.max(1, counts[0]);
    let rows = '';
    f.steps.forEach(function (s, i) {
      const c = counts[i];
      const widthPct = Math.max(2, Math.min(100, c / top * 100));
      const conv = i === 0
        ? (c + ' users')
        : (counts[i - 1] ? Math.round(c / counts[i - 1] * 100) + '% of previous step' : '—');
      rows += '<div class="funnel-row"><span class="fill" style="width:' + widthPct + '%"></span>' +
        '<span class="txt">' + s[1] + ' — ' + c + '</span></div>' +
        '<div class="funnel-conv">' + conv + '</div>';
    });
    const card = document.createElement('div');
    card.className = 'card';
    card.innerHTML = '<div class="chart-meta"><span><b>' + f.title + '</b></span></div><div class="funnel">' + rows + '</div>';
    el.appendChild(card);
  });
}

const COMPARE_GROUPS = [
  { title: 'Adding content', events: [
    ['Browser.AddVideo', 'Add video'], ['Browser.AddSubscription', 'Add subscription'],
    ['Browser.PlayNow', 'Play now'], ['Browser.ContextMenu.AddToInbox', 'Ctx: to inbox'],
    ['Browser.ContextMenu.QueueNext', 'Ctx: queue next'],
  ]},
  { title: 'Player navigation', events: [
    ['Player.NextVideo', 'Next video'], ['Player.NextChapter', 'Next chapter'],
    ['Player.PreviousChapter', 'Prev chapter'], ['Player.PIP', 'Picture-in-picture'],
    ['Player.AirPlay', 'AirPlay'],
  ]},
];

function renderCompare(el, countsByEvent) {
  el.innerHTML = '';
  COMPARE_GROUPS.forEach(function (g, gi) {
    const rows = g.events.map(function (e) { return { label: e[1], count: countsByEvent[e[0]] || 0 }; });
    const max = Math.max(1, Math.max.apply(null, rows.map(function (r) { return r.count; })));
    let html = '';
    rows.forEach(function (r, i) {
      const color = BUCKET_COLORS[(gi * 3 + i) % BUCKET_COLORS.length];
      html += '<div class="cmp-row"><span class="cmp-label">' + r.label + '</span>' +
        '<span class="cmp-track"><span class="cmp-fill" style="width:' + (r.count / max * 100) + '%;background:' + color + '"></span></span>' +
        '<span class="cmp-count">' + r.count + '</span></div>';
    });
    const card = document.createElement('div');
    card.className = 'card';
    card.innerHTML = '<div class="chart-meta"><span><b>' + g.title + '</b></span></div><div class="cmp-chart">' + html + '</div>';
    el.appendChild(card);
  });
}

// Sum counts of one consolidated event, grouped by one of its param keys.
function aggregateParam(paramEvents, eventName, key) {
  const totals = {};
  paramEvents.forEach(function (r) {
    if (r.name !== eventName) return;
    const v = r.params[key];
    if (v == null) return;
    totals[v] = (totals[v] || 0) + r.count;
  });
  return totals;
}

function barCard(title, totals, gi) {
  const entries = Object.entries(totals).sort(function (a, b) { return b[1] - a[1]; });
  const max = Math.max(1, Math.max.apply(null, entries.map(function (e) { return e[1]; })));
  let html = '';
  entries.forEach(function (e, i) {
    const color = BUCKET_COLORS[(gi * 3 + i) % BUCKET_COLORS.length];
    html += '<div class="cmp-row"><span class="cmp-label">' + e[0] + '</span>' +
      '<span class="cmp-track"><span class="cmp-fill" style="width:' + (e[1] / max * 100) + '%;background:' + color + '"></span></span>' +
      '<span class="cmp-count">' + e[1] + '</span></div>';
  });
  if (!entries.length) html = '<div class="hint">No data yet.</div>';
  const card = document.createElement('div');
  card.className = 'card';
  card.innerHTML = '<div class="chart-meta"><span><b>' + title + '</b></span></div><div class="cmp-chart">' + html + '</div>';
  return card;
}

function renderBreakdowns(el, paramEvents) {
  el.innerHTML = '';
  paramEvents = paramEvents || [];
  const copyRows = paramEvents.filter(function (r) { return r.params.action === 'copyUrl'; });
  const queueTopRows = paramEvents.filter(function (r) { return r.params.action === 'queueTop'; });
  el.appendChild(barCard('Video actions — by action', aggregateParam(paramEvents, 'Video.Action', 'action'), 0));
  el.appendChild(barCard('Video actions — by surface', aggregateParam(paramEvents, 'Video.Action', 'context'), 1));
  el.appendChild(barCard('Queue next — by input', aggregateParam(queueTopRows, 'Video.Action', 'via'), 3));
  el.appendChild(barCard('More menu — by action', aggregateParam(paramEvents, 'Player.MoreMenu', 'action'), 2));
  el.appendChild(barCard('Copy URL — by option', aggregateParam(copyRows, 'Player.MoreMenu', 'option'), 0));
}

// State/snapshot events are shown elsewhere; the engagement table is behavioral only.
const NON_BEHAVIORAL = { 'SettingsSnapshot': 1, 'Queue.Count': 1, 'Inbox.Count': 1, 'SubscriptionCount': 1 };

function renderEngagement(tbody, counts, weeklyActive) {
  tbody.innerHTML = '';
  const wau = Math.max(1, Number(weeklyActive) || 0);
  counts.filter(function (r) { return !NON_BEHAVIORAL[r.name]; }).forEach(function (r) {
    const count = Number(r.count) || 0;
    const users = Number(r.users) || 0;
    const rate = count / wau;
    const perUser = rate >= 10 ? Math.round(rate) : rate.toFixed(1);
    const adoption = Math.min(100, Math.round(users / wau * 100));
    const tr = document.createElement('tr');
    tr.innerHTML = '<td>' + r.name + '</td>' +
      '<td class="num">' + count + '</td>' +
      '<td class="num">' + users + '</td>' +
      '<td class="num">' + perUser + '</td>' +
      '<td class="num rate-bar"><span style="width:' + adoption + '%"></span><b>' + adoption + '%</b></td>';
    tbody.appendChild(tr);
  });
}

function renderErrors(chartEl, table, errors) {
  renderLineChart(chartEl, errors.trend, 'count', '#f87171');
  const body = table.querySelector('tbody');
  body.innerHTML = '';
  if (!errors.top.length) {
    body.innerHTML = '<tr><td colspan="2" style="color:#777">No errors reported 🎉</td></tr>';
    return;
  }
  errors.top.forEach(function (r) {
    const tr = document.createElement('tr');
    tr.innerHTML = '<td>' + r.id + '</td><td class="num">' + r.count + '</td>';
    body.appendChild(tr);
  });
}

// Idempotent so the section's refresh button can re-render it on its own without
// duplicating rows. Expand/collapse state is preserved across refreshes.
let recentExpanded = false;
function renderRecent(recent) {
  const recentBody = document.querySelector('#recent tbody');
  recentBody.innerHTML = '';
  const recentRows = [];
  (recent || []).forEach((row) => {
    const tr = document.createElement('tr');
    const when = timeAgo(row.clientTimestamp);
    tr.title = new Date(row.clientTimestamp).toLocaleString();
    // Stripped to bare letters because this goes in via innerHTML and the value
    // comes off the wire.
    const channel = String(row.channel || 'unknown').replace(/[^a-z]/g, '');
    tr.innerHTML = \`<td>\${row.name}</td><td>\${row.params}</td><td>\${channel}</td><td title="\${tr.title}">\${when}</td>\`;
    recentBody.appendChild(tr);
    recentRows.push(tr);
  });
  const recentToggle = document.getElementById('recentToggle');
  const sync = () => {
    recentRows.forEach((tr, i) => tr.classList.toggle('hidden', !recentExpanded && i >= RECENT_COLLAPSED_COUNT));
    recentToggle.textContent = recentExpanded ? 'Show fewer' : 'Show all ' + recentRows.length + ' events';
  };
  if (recentRows.length <= RECENT_COLLAPSED_COUNT) {
    recentToggle.hidden = true;
  } else {
    recentToggle.hidden = false;
    recentToggle.onclick = () => { recentExpanded = !recentExpanded; sync(); };
  }
  sync();
}

const recentRefresh = document.getElementById('recentRefresh');
recentRefresh.onclick = () => {
  recentRefresh.disabled = true;
  recentRefresh.classList.add('spinning');
  fetch('/dashboard/recent' + channelQuery)
    .then((r) => r.json())
    .then((d) => { if (d && d.recent) renderRecent(d.recent); })
    .catch(() => {})
    .finally(() => {
      recentRefresh.disabled = false;
      recentRefresh.classList.remove('spinning');
    });
};

// Data loads async, so restore scroll ourselves instead of letting the browser
// guess against a not-yet-populated page. We restore twice: once now, so the
// skeleton is already scrolled to where the user was, and again after render to
// correct for any height difference between the skeleton and the real content.
const SCROLL_KEY = 'dashboardScroll';
if ('scrollRestoration' in history) history.scrollRestoration = 'manual';
const savedScroll = Number(sessionStorage.getItem(SCROLL_KEY) || 0);
// Don't record scroll while loading: an early restore that clamps to the shorter
// skeleton page would otherwise overwrite the real saved position.
addEventListener('scroll', () => {
  if (!document.body.classList.contains('loading')) sessionStorage.setItem(SCROLL_KEY, String(scrollY));
}, { passive: true });
if (savedScroll) scrollTo(0, savedScroll);
function finishLoading() {
  document.body.classList.remove('loading');
  if (savedScroll) scrollTo(0, savedScroll);
}

fetch('/dashboard/data' + channelQuery).then(r => r.json()).then(data => {
  if (data.error) {
    document.getElementById('error').textContent = data.error;
    finishLoading();
    return;
  }

  const activeEl = document.getElementById('activeUsers');
  const activeLabels = { daily: 'DAU (24h)', weekly: 'WAU (7d)', monthly: 'MAU (30d)' };
  for (const key in activeLabels) {
    const card = document.createElement('div');
    card.className = 'stat-card';
    card.innerHTML = '<div class="value">' + (data.activeUsers[key] ?? 0) + '</div><div class="label">' + activeLabels[key] + '</div>';
    activeEl.appendChild(card);
  }

  renderLineChart(document.getElementById('dauTrend'), data.activeUsersTrend, 'users', '#4ade80');

  document.getElementById('platformHint').textContent =
    'Based on ' + data.platform.sampleSize + ' users active in the last ' + data.platform.windowDays + ' days';
  renderPie(document.getElementById('devicePie'), data.platform.devices);
  renderOsPie(document.getElementById('osPie'), data.platform.os);

  const countsByEvent = {}, usersByEvent = {};
  (data.counts || []).forEach(function (r) {
    countsByEvent[r.name] = Number(r.count) || 0;
    usersByEvent[r.name] = Number(r.users) || 0;
  });

  const win = '(last ' + data.trendWindowDays + ' days)';
  document.getElementById('engagementWindow').textContent = win;
  renderEngagement(document.querySelector('#engagement tbody'), data.counts || [], data.activeUsers.weekly);

  renderLineChart(document.getElementById('eventTrend'), data.eventTrend, 'events', '#3b82f6');

  var writes = data.writes || {};
  document.getElementById('writesHint').textContent =
    'Data points written/day (one per event) vs. the ' + fmtNum(writes.freeDailyLimit || 0) +
    '/day free-plan cap. Requests are batched (up to 25 events each), so this line — the write count — is the upper bound on both caps. Always counts every channel, including debug: all writes bill the same.';
  renderLineChart(document.getElementById('writesTrend'), writes.trend, 'writes', '#fbbf24', writes.freeDailyLimit || 0);

  document.getElementById('funnelHint').textContent = 'Distinct users reaching each step ' + win;
  renderFunnels(document.getElementById('funnels'), usersByEvent);

  document.getElementById('compareHint').textContent = 'Total event counts ' + win;
  renderCompare(document.getElementById('compare'), countsByEvent);

  document.getElementById('breakdownHint').textContent = 'Consolidated events broken out by their parameters ' + win;
  document.getElementById('playbackStartWindow').textContent = '(last ' + data.trendWindowDays + ' days)';
  renderPie(document.getElementById('playbackStartPie'), aggregateParam(data.paramEvents || [], 'Player.Start', 'source'));

  renderBreakdowns(document.getElementById('breakdowns'), data.paramEvents);

  document.getElementById('settingsHint').textContent =
    'Based on ' + data.settings.sampleSize + ' users active in the last ' + data.settings.windowDays + ' days';
  renderSettingsGrid(document.getElementById('settingsGrid'), document.getElementById('settingsToggle'), data.settings);

  document.getElementById('queueHint').textContent =
    'Based on ' + data.queueInbox.queue.sampleSize + ' users active in the last ' + data.queueInbox.windowDays + ' days';
  renderPie(document.getElementById('queuePie'), data.queueInbox.queue.buckets);

  document.getElementById('inboxHint').textContent =
    'Based on ' + data.queueInbox.inbox.sampleSize + ' users active in the last ' + data.queueInbox.windowDays + ' days';
  renderPie(document.getElementById('inboxPie'), data.queueInbox.inbox.buckets);

  document.getElementById('subsHint').textContent =
    'Based on ' + data.subscriptions.sampleSize + ' users active in the last ' + data.subscriptions.windowDays + ' days';
  renderPie(document.getElementById('subsPie'), data.subscriptions.buckets);

  document.getElementById('errorWindow').textContent = '(last ' + data.errors.windowDays + ' days)';
  renderErrors(document.getElementById('errorTrend'), document.getElementById('errors'), data.errors);

  renderRecent(data.recent);
  finishLoading();
}).catch(err => {
  document.getElementById('error').textContent = err;
  finishLoading();
});
</script>
</body>
</html>`;
