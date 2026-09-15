# Unwatched Analytics

Privacy-first, self-hosted product analytics. Two halves:

- **App side** — `Signal.log()` in `Unwatched/Unwatched/Helper/Signal.swift` enqueues events; `AnalyticsQueue` batches and POSTs them to the Worker. Event shape in `AnalyticsEvent.swift`.
- **Worker side** — `cloudflare-worker/src/` ingests events into a Cloudflare Analytics Engine dataset (`unwatched_analytics_v3`) and serves the `/dashboard`.

Analytics Engine is **append-only** — no `UPDATE`, `DELETE` or `TRUNCATE`, and rows expire on their
own after three months. A dataset therefore can't be cleaned or backfilled: the only reset is to
bump the dataset name in `wrangler.toml` (and every query in `dashboard.js`) and let the old one age
out. That's what `_v3` is — the cutover when build channels landed, discarding a dataset that only
ever held local test events. Weigh it accordingly once real data is flowing.

## Guiding principle

> Detailed enough to make product decisions, never more. Every event must be anonymous, aggregate-only, and justified by a decision it informs. When in doubt, don't log it — or log less of it.

Concretely, before adding or changing a signal, it must pass all of:

1. **Names a decision.** "Should we keep/change/promote feature X?" If you can't state the decision, don't add the event.
2. **Anonymous.** The only identifier is `AnalyticsEvent.anonymousUserId` — a random per-install UUID in local `UserDefaults`, reset on reinstall, excluded from iCloud sync/backup. Never log anything that could identify a person or their content.
3. **No free text or content.** Never log video titles, channel names, URLs, search queries, playlist names, file paths, or error strings. See "What never gets logged" below.
4. **Bounded cardinality.** Event names and parameter values come from a small, fixed, code-defined set. Counts go through `Signal.bucket()` (ranges like `10-24`), never raw values that could be uniquely identifying.
5. **Bounded volume.** One event per deliberate user action. Anything that can fire in a loop, on a gesture drag, on scroll, or on `onAppear` of a common view must be throttled (`SignalInterval`) or moved to a single commit point. A signal that can fire dozens of times per minute per user will flood the dataset and cost money.
6. **Volume or adoption, decided on purpose.** An event whose count scales with a user's *content* rather than their sessions (a per-row list action, a per-chapter tap) is throttled daily and read as "people who did this today". Only events whose raw count is itself the metric — `Player.Start`, `Player.WatchedVideo`, the browser add-flows — stay unthrottled. Events compared against each other in the dashboard must be on the same side of this line, or the chart compares taps against user-days.

## What never gets logged

- Search query text (stored locally only — never sent).
- Any user-entered string. **Never add a free-text setting to `Const.settingsDefaults` / `syncedSettingsDefaults`** — `SettingsSnapshot` serializes every non-default setting value, so a free-text setting would leak straight into analytics. Snapshot values must stay bool / enum / number.
- Raw counts that could be fingerprinting — bucket them with `Signal.bucket()`.
- Exception/error *messages*. `Signal.error(id)` takes a short, fixed id only, and is logged without a `userId` — an error moment should never build a per-user profile or count toward active users.

## App version

Every event also carries `Signal.appVersion` (`blob5`) — the marketing version, with the build
number appended off release where several builds share one version. On every event rather than
only on the snapshot, so any figure can be split by release; a fortnightly snapshot can't tell
"this error started in 2.1" from "this user reports rarely". Optional in `AnalyticsEvent` for the
same decoding reason as `channel`; the Worker maps a missing one to `unknown`.

## Build channels

Every event carries a `channel` — `debug` (local dev builds), `testflight`, or `release` — from
`Signal.buildChannel`, stored as `blob4`. The point is to keep local testing out of the live
numbers *without* dropping it: debug events still ingest, so the analytics path stays exercised
in development instead of only being proven after release.

- **Dashboard default is `live`** = `blob4 IN ('release', 'testflight')`. The picker in the header
  switches channel via `?channel=`; anything other than the default is highlighted and captioned so
  debug numbers can't be misread as real ones. Valid values are the keys of `CHANNEL_FILTERS` in
  `dashboard.js` — the query value is looked up there, never interpolated. `live` is an allowlist
  rather than "not debug" so a channel added to the app, or an `unknown` from a payload that didn't
  come from a real build, can't land in the live numbers before it's deliberately let in.
- **The capacity/writes chart is deliberately unfiltered** — debug writes bill against the free-plan
  cap exactly like release ones, so it has to show every row actually written.
- **Throttle keys are namespaced in debug** (`Signal.log`): a dev build shares `UserDefaults` with an
  installed release build, so an un-namespaced key would let local testing consume the
  weekly/fortnightly snapshot window and suppress the real user's snapshot.
- `AnalyticsEvent.channel` is `String?` only for backward compatibility — a non-optional would fail
  to decode queue files written by an older build and drop every event in them.

## Conventions

- **Naming:** `Area.Action` in PascalCase, e.g. `Player.NextVideo`, `Search.Submitted`. Group related actions under one event with a low-cardinality parameter rather than exploding into many event names, e.g. `Player.MoreMenu` with `action: "reload" | "bookmark" | "defer"`.
- **Parameters:** `[String: String]`, keys from a fixed set, values low-cardinality (enums, `On`/`Off`, buckets). A parameter named `*.Value` is a bucket string.
- **Context over duplication:** prefer one event carrying a context parameter (e.g. `context: "search" | "queue" | "inbox"`, `fullscreen: "portrait" | "landscape" | "off"`) over separate event names per surface.
- **Snapshots vs actions:** state (queue size, settings, subscription count) is sampled as a *throttled snapshot* (`.weekly` / `.fortNightly`) and de-duped to the latest per user in the Worker. Actions are logged once per occurrence.
- **Opt-out:** all logging is gated on `Const.analytics` and runs on iOS + visionOS (`#if os(iOS) || os(visionOS)`). Preserve both guards. (macOS/tvOS do not report.) Turning it *off* goes through `Signal.handleOptOut()`, not `Signal.log`: by the time the toggle's `onChange` runs the setting is already written, so the normal path would swallow it and only opt-ins would ever be recorded. It drops the pending queue and sends one unidentified `Analytics`/`Off` event, so nothing collected before the opt-out is transmitted after it.
- **Device/OS:** `Signal.deviceCategory` (iPhone/iPad/Vision Pro/…) and `Signal.osVersion` (platform + major.minor, patch dropped) ride along on the `SettingsSnapshot` so they're deduped per user like settings.

## Throttling

`Signal.log(name, throttle:)` with a `SignalInterval` rate-limits per install (backed by `UserDefaults` last-sent timestamps). The opt-out is checked *before* the throttle, so an opted-out install doesn't silently consume its own weekly/fortnightly windows.

- **Snapshots:** `Queue.Count`/`Inbox.Count` weekly, `SettingsSnapshot`/`SubscriptionCount` fortnightly.
- **`Signal.interaction(name, variant)`** — the shared daily throttle for repeatable player interactions (`Player.MoreMenu`, `Player.PIP`, `Player.NextVideo`, `Player.NextChapter`, `Chapter.*`, `Player.Media`, …). Use it for anything tappable more than once a session.
- **`Signal.videoAction`** throttles daily per action+context+via — its volume scales with how much content a person has, not how much they use the app.
- **`Signal.gesture`** daily per gesture type; **`Signal.error`** hourly per id, so a retry loop reports once rather than thousands of times.
- **Unthrottled on purpose:** `Player.Start`, `Player.WatchedVideo` (engagement volume), the `Browser.*` add-flows, `Onboarding.Step` (once per install anyway) and `Generation.Result` (slow and deliberate).

## Dashboard (Worker)

- `src/index.js` — ingestion (`POST /`, bearer `API_SECRET`) + dashboard auth.
- `src/dashboard.js` — `handleDashboardData(env, channel)` (SQL queries) + `DASHBOARD_HTML` (inline UI).
- Auth: HTTP Basic, upgraded to a 30-day rolling `HttpOnly; Secure` cookie (`dashboard_auth`, SHA-256 of the password).
- Analytics Engine SQL is a ClickHouse subset. Confirmed available: `count(DISTINCT …)`, `toStartOfDay`, `toStartOfInterval`, `now()`. No `uniq()`.
- `BOOL_SETTINGS` and `VALUE_SETTINGS` in `dashboard.js` mirror the app's settings **manually** — keep both in sync when a setting is added, renamed or removed, *including its default*. A snapshot only carries settings moved off their default, so the dashboard folds every absent user onto the default side: a wrong default there flips the majority of a chart rather than losing a row. `VALUE_SETTINGS` raw values are Swift `rawValue`s, so reordering an enum without explicit raw values silently rewrites the meaning of historical rows.
- Settings cards report two separate things on purpose: the **distribution** (default-folded, "where people are") and **changed by N** ("how many went and moved it"). A setting that's 95% on because it ships on and one that's 95% on because people turn it on are the same donut and opposite decisions.
- `handleDashboardData()` fans out ~15 concurrent queries; if you add more, watch rate limits. Each dashboard load spends that many of the free plan's 10k/day Analytics Engine **read queries** — fine for occasional use, but don't poll/auto-refresh aggressively.
- Raw-row queries (`SettingsSnapshot`, `Queue.Count`/`Inbox.Count`, `SubscriptionCount`) are capped at `RAW_ROW_LIMIT` and ordered newest-first, so hitting the cap drops the oldest rows rather than an arbitrary slice.

## Dev

```
npm run dev                    # local (note: Secure cookie won't persist over http://localhost)
npx wrangler deploy --dry-run  # bundle without shipping — the only real syntax check
npm run deploy                 # wrangler deploy
npm run tail                   # live logs
```

`node --check src/dashboard.js` is **not** enough: the whole UI lives inside the `DASHBOARD_HTML`
template literal, so a stray backtick in a comment there closes the string early and the remainder
can still parse as valid JS. Only esbuild (what `wrangler deploy` runs) rejects it. Never use
backticks inside `DASHBOARD_HTML` — quote identifiers with `'` in comments there.
