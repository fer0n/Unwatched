export const RAW_ROW_LIMIT = 20000;
export const SNAPSHOT_WINDOW_DAYS = 30;
export const HISTORY_WINDOW_DAYS = 90;
export const WEEKLY_PERIOD_DAYS = 7;
export const FORTNIGHTLY_PERIOD_DAYS = 14;
export const DAY_MS = 24 * 60 * 60 * 1000;
// Window for per-event engagement metrics (counts, per-user rates, funnels).
export const TREND_WINDOW_DAYS = 7;
// Window for the capacity chart — enough history to spot a trend toward the free-plan cap.
export const CAPACITY_WINDOW_DAYS = 30;
// Long enough to see search vs YouTube use before and after a release.
export const SEARCH_WINDOW_DAYS = 30;
// Cloudflare Workers Free plan: 100k requests/day AND 100k Analytics Engine data points
// written/day. Requests are batched (<=25 events each), so writes/day is the larger of the
// two and the one to watch. Kept here so the server can hand it to the client chart.
export const FREE_DAILY_LIMIT = 100000;
