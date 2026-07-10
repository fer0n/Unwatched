# Unwatched Analytics

Privacy-first, self-hosted product analytics. Two halves:

- **App side** — `Signal.log()` in `Unwatched/Unwatched/Helper/Signal.swift` enqueues events; `AnalyticsQueue` batches and POSTs them to the Worker. Event shape in `AnalyticsEvent.swift`.
- **Worker side** — `cloudflare-worker/src/` ingests events into a Cloudflare Analytics Engine dataset (`unwatched_analytics_v2`) and serves the `/dashboard`.

## Guiding principle

> Detailed enough to make product decisions, never more. Every event must be anonymous, aggregate-only, and justified by a decision it informs. When in doubt, don't log it — or log less of it.

Concretely, before adding or changing a signal, it must pass all of:

1. **Names a decision.** "Should we keep/change/promote feature X?" If you can't state the decision, don't add the event.
2. **Anonymous.** The only identifier is `AnalyticsEvent.anonymousUserId` — a random per-install UUID in local `UserDefaults`, reset on reinstall, excluded from iCloud sync/backup. Never log anything that could identify a person or their content.
3. **No free text or content.** Never log video titles, channel names, URLs, search queries, playlist names, file paths, or error strings. See "What never gets logged" below.
4. **Bounded cardinality.** Event names and parameter values come from a small, fixed, code-defined set. Counts go through `Signal.bucket()` (ranges like `10-24`), never raw values that could be uniquely identifying — except deliberate low-cardinality counts like `SubscriptionCount`.
5. **Bounded volume.** One event per deliberate user action. Anything that can fire in a loop, on a gesture drag, on scroll, or on `onAppear` of a common view must be throttled (`SignalInterval`) or moved to a single commit point. A signal that can fire dozens of times per minute per user will flood the dataset and cost money.

## What never gets logged

- Search query text (stored locally only — never sent).
- Any user-entered string. **Never add a free-text setting to `Const.settingsDefaults` / `syncedSettingsDefaults`** — `SettingsSnapshot` serializes every non-default setting value, so a free-text setting would leak straight into analytics. Snapshot values must stay bool / enum / number.
- Raw counts that could be fingerprinting — bucket them with `Signal.bucket()`.
- Exception/error *messages*. `Signal.error(id)` takes a short, fixed id only.

## Conventions

- **Naming:** `Area.Action` in PascalCase, e.g. `Player.NextVideo`, `Search.Submitted`. Group related actions under one event with a low-cardinality parameter rather than exploding into many event names, e.g. `Player.MoreMenu` with `action: "reload" | "bookmark" | "defer"`.
- **Parameters:** `[String: String]`, keys from a fixed set, values low-cardinality (enums, `On`/`Off`, buckets). A parameter named `*.Value` is a bucket string.
- **Context over duplication:** prefer one event carrying a context parameter (e.g. `context: "search" | "queue" | "inbox"`, `fullscreen: "portrait" | "landscape" | "off"`) over separate event names per surface.
- **Snapshots vs actions:** state (queue size, settings, subscription count) is sampled as a *throttled snapshot* (`.weekly` / `.fortNightly`) and de-duped to the latest per user in the Worker. Actions are logged once per occurrence.
- **Opt-out:** all logging is gated on `Const.analytics` and runs on iOS + visionOS (`#if os(iOS) || os(visionOS)`). Preserve both guards. (macOS/tvOS do not report.)
- **Device/OS:** `Signal.deviceCategory` (iPhone/iPad/Vision Pro/…) and `Signal.osVersion` (platform + major.minor, patch dropped) ride along on the `SettingsSnapshot` so they're deduped per user like settings.

## Throttling

`Signal.log(name, throttle:)` with a `SignalInterval` rate-limits per install (backed by `UserDefaults` last-sent timestamps). Use it for snapshots and for any event at risk of firing repeatedly. Snapshots today: `Queue.Count`/`Inbox.Count` weekly, `SettingsSnapshot`/`SubscriptionCount` fortnightly.

## Dashboard (Worker)

- `src/index.js` — ingestion (`POST /`, bearer `API_SECRET`) + dashboard auth.
- `src/dashboard.js` — `handleDashboardData()` (SQL queries) + `DASHBOARD_HTML` (inline UI).
- Auth: HTTP Basic, upgraded to a 30-day rolling `HttpOnly; Secure` cookie (`dashboard_auth`, SHA-256 of the password).
- Analytics Engine SQL is a ClickHouse subset. Confirmed available: `count(DISTINCT …)`, `toStartOfDay`, `toStartOfInterval`, `now()`. No `uniq()`.
- `BOOL_SETTINGS` in `dashboard.js` mirrors the app's boolean settings **manually** — keep it in sync when settings are added/removed.
- `handleDashboardData()` fans out ~14 concurrent queries; if you add more, watch rate limits. Each dashboard load spends that many of the free plan's 10k/day Analytics Engine **read queries** — fine for occasional use, but don't poll/auto-refresh aggressively.

## Dev

```
npm run dev      # local (note: Secure cookie won't persist over http://localhost)
npm run deploy   # wrangler deploy
npm run tail     # live logs
```
