import { RAW_ROW_LIMIT, SNAPSHOT_WINDOW_DAYS, HISTORY_WINDOW_DAYS, WEEKLY_PERIOD_DAYS, FORTNIGHTLY_PERIOD_DAYS, DAY_MS, TREND_WINDOW_DAYS, CAPACITY_WINDOW_DAYS, SEARCH_WINDOW_DAYS, FREE_DAILY_LIMIT } from "./constants.js";
import { parseParams, latestPerUser, tallySettings, tallyValueSettings, tallyBuckets, tallyRawBuckets, tallyDevices, serverTime, latestPerUserPerPeriod, platformTrend, settingsTrend, bucketTrend, YOUTUBE_PAGE_EVENTS, tallySearchUsage, tallyParam } from "./aggregate.js";

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

// Same order as the queries in handleDashboardData.
const QUERY_LABELS = [
  "event counts",
  "recent events",
  "active users (1d)",
  "active users (7d)",
  "active users (30d)",
  "active users trend",
  "event trend",
  "writes trend",
  "settings snapshots",
  "queue/inbox sizes",
  "subscription counts",
  "errors",
  "error trend",
  "param events",
  "app versions",
  "search usage",
  "search usage versions",
  "weekly active users trend",
  "monthly active users trend",
  "app versions trend",
  "queue/inbox trend",
  "subscription trend",
];

export async function handleDashboardData(env, channel) {
  const ch = channelFilter(channel);
  try {
    // allSettled: a column no row has written yet 422s its query, which shouldn't blank the page
    const settled = await Promise.allSettled([
      // Per-event totals AND distinct users over 7d — powers the engagement
      // table (per-active-user rates, adoption %), funnels, and comparisons.
      queryAnalytics(
        env,
        `SELECT blob1 AS name, sum(_sample_interval) AS count, count(DISTINCT blob3) AS users FROM unwatched_analytics_v3 WHERE ${ch} AND timestamp > NOW() - INTERVAL '${TREND_WINDOW_DAYS}' DAY AND blob3 != 'unknown' GROUP BY name ORDER BY count DESC LIMIT 200`
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
      queryAnalytics(
        env,
        `SELECT toStartOfDay(timestamp) AS day, count(DISTINCT blob3) AS users FROM unwatched_analytics_v3 WHERE ${ch} AND timestamp > NOW() - INTERVAL '${HISTORY_WINDOW_DAYS}' DAY AND blob3 != 'unknown' GROUP BY day ORDER BY day`
      ),
      // Total event volume per day over the trend window.
      queryAnalytics(
        env,
        `SELECT toStartOfDay(timestamp) AS day, sum(_sample_interval) AS events FROM unwatched_analytics_v3 WHERE ${ch} AND timestamp > NOW() - INTERVAL '${TREND_WINDOW_DAYS}' DAY GROUP BY day ORDER BY day`
      ),
      // Data points written per day over a longer window. Billing counts every writeDataPoint
      // call, before Analytics Engine samples rows away, so sum(_sample_interval) estimates the
      // "data points written" metric where count() would undercount it. Since a request batches
      // up to 25 events, writes/day is an upper bound on requests/day, so one line answers both
      // free-plan caps (see FREE_DAILY_LIMIT).
      // Deliberately NOT channel-filtered: debug and TestFlight writes bill the same as
      // release ones, so the capacity chart has to show every data point written.
      queryAnalytics(
        env,
        `SELECT toStartOfDay(timestamp) AS day, sum(_sample_interval) AS writes FROM unwatched_analytics_v3 WHERE timestamp > NOW() - INTERVAL '${CAPACITY_WINDOW_DAYS}' DAY GROUP BY day ORDER BY day`
      ),
      // ORDER BY only resolves selected columns, hence the alias
      queryAnalytics(
        env,
        `SELECT blob2 AS params, blob3 AS userId, double1 AS ts, timestamp AS at FROM unwatched_analytics_v3 WHERE ${ch} AND blob1 = 'SettingsSnapshot' AND timestamp > NOW() - INTERVAL '${HISTORY_WINDOW_DAYS}' DAY ORDER BY ts DESC LIMIT ${RAW_ROW_LIMIT}`
      ),
      queryAnalytics(
        env,
        `SELECT blob1 AS name, blob2 AS params, blob3 AS userId, double1 AS ts FROM unwatched_analytics_v3 WHERE ${ch} AND blob1 IN ('Queue.Count', 'Inbox.Count') AND timestamp > NOW() - INTERVAL '${SNAPSHOT_WINDOW_DAYS}' DAY ORDER BY ts DESC LIMIT ${RAW_ROW_LIMIT}`
      ),
      queryAnalytics(
        env,
        `SELECT blob2 AS params, blob3 AS userId, double1 AS ts FROM unwatched_analytics_v3 WHERE ${ch} AND blob1 = 'SubscriptionCount' AND timestamp > NOW() - INTERVAL '${SNAPSHOT_WINDOW_DAYS}' DAY ORDER BY ts DESC LIMIT ${RAW_ROW_LIMIT}`
      ),
      queryAnalytics(
        env,
        `SELECT blob2 AS params, sum(_sample_interval) AS count FROM unwatched_analytics_v3 WHERE ${ch} AND blob1 = 'Error' AND timestamp > NOW() - INTERVAL '${SNAPSHOT_WINDOW_DAYS}' DAY GROUP BY params ORDER BY count DESC LIMIT 50`
      ),
      queryAnalytics(
        env,
        `SELECT toStartOfDay(timestamp) AS day, sum(_sample_interval) AS count FROM unwatched_analytics_v3 WHERE ${ch} AND blob1 = 'Error' AND timestamp > NOW() - INTERVAL '${SNAPSHOT_WINDOW_DAYS}' DAY GROUP BY day ORDER BY day`
      ),
      // Consolidated param-carrying events, grouped by their raw params JSON so the
      // client can break them out by dimension (Video.Action by action/context, etc).
      queryAnalytics(
        env,
        `SELECT blob1 AS name, blob2 AS params, sum(_sample_interval) AS count FROM unwatched_analytics_v3 WHERE ${ch} AND blob1 IN ('Video.Action', 'Player.MoreMenu', 'Search.Submitted', 'Player.Start', 'Player.Media', 'Onboarding.Step', 'Generation.Result', 'Subscription.Added', 'Premium.ShowPopup') AND timestamp > NOW() - INTERVAL '${TREND_WINDOW_DAYS}' DAY GROUP BY name, params ORDER BY count DESC LIMIT 1000`
      ),
      // Distinct users per app version (blob5).
      queryAnalytics(
        env,
        `SELECT blob5 AS version, count(DISTINCT blob3) AS users FROM unwatched_analytics_v3 WHERE ${ch} AND timestamp > NOW() - INTERVAL '${TREND_WINDOW_DAYS}' DAY AND blob3 != 'unknown' GROUP BY version ORDER BY users DESC LIMIT 40`
      ),
      queryAnalytics(
        env,
        `SELECT toStartOfDay(timestamp) AS day, blob3 AS userId, blob5 AS version, blob1 AS name, blob2 AS params, sum(_sample_interval) AS count FROM unwatched_analytics_v3 WHERE ${ch} AND (blob1 IN ('Search.Submitted', 'Search.YoutubeMode', ${YOUTUBE_PAGE_EVENTS.map((e) => `'${e}'`).join(', ')}) OR (blob1 = 'Player.Start' AND blob2 = '{"source":"browserTap"}')) AND timestamp > NOW() - INTERVAL '${SEARCH_WINDOW_DAYS}' DAY AND blob3 != 'unknown' GROUP BY day, userId, version, name, params LIMIT ${RAW_ROW_LIMIT}`
      ),
      queryAnalytics(
        env,
        `SELECT blob5 AS version, count(DISTINCT blob3) AS users FROM unwatched_analytics_v3 WHERE ${ch} AND timestamp > NOW() - INTERVAL '${SEARCH_WINDOW_DAYS}' DAY AND blob3 != 'unknown' GROUP BY version ORDER BY users DESC LIMIT 8`
      ),
      queryAnalytics(
        env,
        `SELECT toStartOfInterval(timestamp, INTERVAL '${WEEKLY_PERIOD_DAYS}' DAY) AS day, count(DISTINCT blob3) AS users FROM unwatched_analytics_v3 WHERE ${ch} AND timestamp > NOW() - INTERVAL '${HISTORY_WINDOW_DAYS}' DAY AND blob3 != 'unknown' GROUP BY day ORDER BY day`
      ),
      queryAnalytics(
        env,
        `SELECT toStartOfMonth(timestamp) AS day, count(DISTINCT blob3) AS users FROM unwatched_analytics_v3 WHERE ${ch} AND timestamp > NOW() - INTERVAL '${HISTORY_WINDOW_DAYS}' DAY AND blob3 != 'unknown' GROUP BY day ORDER BY day`
      ),
      queryAnalytics(
        env,
        `SELECT toStartOfDay(timestamp) AS day, blob5 AS version, count(DISTINCT blob3) AS users FROM unwatched_analytics_v3 WHERE ${ch} AND timestamp > NOW() - INTERVAL '${HISTORY_WINDOW_DAYS}' DAY AND blob3 != 'unknown' GROUP BY day, version ORDER BY day DESC LIMIT ${RAW_ROW_LIMIT}`
      ),
      queryAnalytics(
        env,
        `SELECT toStartOfInterval(timestamp, INTERVAL '${WEEKLY_PERIOD_DAYS}' DAY) AS period, blob1 AS name, blob2 AS params, count(DISTINCT blob3) AS users FROM unwatched_analytics_v3 WHERE ${ch} AND blob1 IN ('Queue.Count', 'Inbox.Count') AND timestamp > NOW() - INTERVAL '${HISTORY_WINDOW_DAYS}' DAY AND blob3 != 'unknown' GROUP BY period, name, params ORDER BY period DESC LIMIT ${RAW_ROW_LIMIT}`
      ),
      queryAnalytics(
        env,
        `SELECT toStartOfInterval(timestamp, INTERVAL '${FORTNIGHTLY_PERIOD_DAYS}' DAY) AS period, blob2 AS params, count(DISTINCT blob3) AS users FROM unwatched_analytics_v3 WHERE ${ch} AND blob1 = 'SubscriptionCount' AND timestamp > NOW() - INTERVAL '${HISTORY_WINDOW_DAYS}' DAY AND blob3 != 'unknown' GROUP BY period, params ORDER BY period DESC LIMIT ${RAW_ROW_LIMIT}`
      ),
    ]);

    const failures = [];
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
      versionsRaw,
      searchUsageRaw,
      searchVersionsRaw,
      wauTrend,
      mauTrend,
      versionsTrendRaw,
      queueInboxTrendRaw,
      subscriptionTrendRaw,
    ] = settled.map((result, index) => {
      if (result.status === "fulfilled") return result.value;
      failures.push(`${QUERY_LABELS[index] ?? `query ${index}`}: ${result.reason}`);
      return { data: [] };
    });

    // Every row here has one userId per app instance, never anything identifying
    // (see AnalyticsEvent.anonymousUserId) — de-duped down to one snapshot per user.
    const snapshotCutoff = Date.now() - SNAPSHOT_WINDOW_DAYS * DAY_MS;
    const latestSettings = latestPerUser(settingsRaw.data.filter((r) => serverTime(r.at) > snapshotCutoff));
    const settingsTruncated = settingsRaw.data.length >= RAW_ROW_LIMIT;
    const settingsPeriods = latestPerUserPerPeriod(settingsRaw.data, FORTNIGHTLY_PERIOD_DAYS);
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
        failures,
        // count/users are per-event over TREND_WINDOW_DAYS; the client derives
        // per-active-user rates and adoption % against activeUsers.
        counts: counts.data,
        trendWindowDays: TREND_WINDOW_DAYS,
        recent: recent.data,
        activeUsers,
        activeUsersTrend: {
          windowDays: HISTORY_WINDOW_DAYS,
          daily: dauTrend.data,
          weekly: wauTrend.data,
          monthly: mauTrend.data,
        },
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
          values: tallyValueSettings(latestSettings),
          trendWindowDays: HISTORY_WINDOW_DAYS,
          trendPeriodDays: FORTNIGHTLY_PERIOD_DAYS,
          trend: settingsTrend(settingsPeriods),
          trendTruncated: settingsTruncated,
        },
        versions: versionsRaw.data.map((r) => ({
          version: r.version || "unknown",
          users: Number(r.users) || 0,
        })),
        versionsTrend: {
          windowDays: HISTORY_WINDOW_DAYS,
          rows: versionsTrendRaw.data.map((r) => ({
            day: r.day,
            version: r.version || "unknown",
            users: Number(r.users) || 0,
          })),
        },
        // Device family + OS version per user, carried on the settings snapshot.
        platform: {
          windowDays: SNAPSHOT_WINDOW_DAYS,
          sampleSize: latestSettings.length,
          devices: tallyDevices(latestSettings),
          os: tallyParam(latestSettings, "os"),
          // Only present for users whose watch has reported in — see WatchRemoteCommand.reportSyncMode.
          watchFullSync: tallyParam(latestSettings, "watchFullSync"),
          trendWindowDays: HISTORY_WINDOW_DAYS,
          trendPeriodDays: FORTNIGHTLY_PERIOD_DAYS,
          trend: platformTrend(settingsPeriods),
          trendTruncated: settingsTruncated,
        },
        queueInbox: {
          windowDays: SNAPSHOT_WINDOW_DAYS,
          queue: { sampleSize: latestQueue.length, buckets: tallyBuckets(latestQueue, "Queue.Count.Value") },
          inbox: { sampleSize: latestInbox.length, buckets: tallyBuckets(latestInbox, "Inbox.Count.Value") },
          trendWindowDays: HISTORY_WINDOW_DAYS,
          trendPeriodDays: WEEKLY_PERIOD_DAYS,
          queueTrend: bucketTrend(queueInboxTrendRaw.data, "Queue.Count.Value", "Queue.Count"),
          inboxTrend: bucketTrend(queueInboxTrendRaw.data, "Inbox.Count.Value", "Inbox.Count"),
        },
        subscriptions: {
          windowDays: SNAPSHOT_WINDOW_DAYS,
          sampleSize: latestSubs.length,
          buckets: tallyRawBuckets(latestSubs, "SubscriptionCount.Value"),
          podcastSampleSize: latestSubs.filter((r) => parseParams(r.params)["PodcastCount.Value"] != null).length,
          podcastBuckets: tallyRawBuckets(latestSubs, "PodcastCount.Value"),
          trendWindowDays: HISTORY_WINDOW_DAYS,
          trendPeriodDays: FORTNIGHTLY_PERIOD_DAYS,
          trend: bucketTrend(subscriptionTrendRaw.data, "SubscriptionCount.Value"),
          podcastTrend: bucketTrend(subscriptionTrendRaw.data, "PodcastCount.Value"),
        },
        errors: {
          windowDays: SNAPSHOT_WINDOW_DAYS,
          top: errorsRaw.data.map((r) => ({ id: parseParams(r.params).id ?? "unknown", count: Number(r.count) })),
          trend: errorTrend.data,
        },
        searchUsage: tallySearchUsage(searchUsageRaw.data, searchVersionsRaw.data),
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
