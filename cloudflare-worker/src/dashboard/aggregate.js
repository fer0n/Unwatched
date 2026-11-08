import { BOOL_SETTINGS, VALUE_SETTINGS, SETTINGS_VALUE_PREFIX, SUBSCRIPTION_SETTINGS } from "./settings.js";
import { DAY_MS, SEARCH_WINDOW_DAYS } from "./constants.js";

export const COUNT_BUCKET_ORDER = ["0", "1-4", "5-9", "10-24", "25-49", "50-99", "100-499", "500-999", "1000+"];

export function parseParams(json) {
  try {
    return JSON.parse(json) ?? {};
  } catch {
    return {};
  }
}

// Keeps only the most recent row per userId (rows must be pre-sorted or we compare timestamps).
export function latestPerUser(rows) {
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

export function settingValue(params, key) {
  if (!Object.prototype.hasOwnProperty.call(params, key)) return null;
  const raw = String(params[key]);
  return raw.startsWith(SETTINGS_VALUE_PREFIX) ? raw.slice(SETTINGS_VALUE_PREFIX.length) : raw;
}

// Users missing from a snapshot count toward the default; 'changed' is how many moved it.
export function tallySettings(latestSnapshots) {
  const totals = {};
  for (const [key, defaultValue, label] of BOOL_SETTINGS) {
    totals[key] = { label, default: defaultValue, on: 0, off: 0, changed: 0, total: 0 };
  }
  for (const row of latestSnapshots) {
    const params = parseParams(row.params);
    for (const [key, defaultValue] of BOOL_SETTINGS) {
      const entry = totals[key];
      entry.total++;
      const raw = settingValue(params, key);
      if (raw === null) {
        if (defaultValue) entry.on++; else entry.off++;
        continue;
      }
      entry.changed++;
      const isOn = raw === "true" ? true : raw === "false" ? false : Number(raw) !== 0;
      if (isOn) entry.on++; else entry.off++;
    }
  }
  return totals;
}

export function tallyValueSettings(latestSnapshots) {
  const totals = {};
  for (const [key, defaultValue, label, valueLabels, unit] of VALUE_SETTINGS) {
    totals[key] = {
      label,
      default: String(defaultValue),
      defaultLabel: valueLabels ? (valueLabels[defaultValue] ?? String(defaultValue)) : String(defaultValue),
      unit: unit ?? "",
      hasLabels: !!valueLabels,
      values: {},
      changed: 0,
      total: 0,
    };
  }
  const bump = (entry, value, valueLabels) => {
    // "2.0" and "2" are the same value
    const num = Number(value);
    const normalized = Number.isFinite(num) ? String(num) : String(value);
    const label = valueLabels ? (valueLabels[normalized] ?? normalized) : normalized;
    entry.values[label] = (entry.values[label] || 0) + 1;
  };
  for (const row of latestSnapshots) {
    const params = parseParams(row.params);
    for (const [key, defaultValue, , valueLabels] of VALUE_SETTINGS) {
      const entry = totals[key];
      entry.total++;
      const raw = settingValue(params, key);
      if (raw === null) {
        bump(entry, defaultValue, valueLabels);
        continue;
      }
      entry.changed++;
      bump(entry, raw, valueLabels);
    }
  }
  return totals;
}

export function tallyBuckets(latestRows, paramKey) {
  const counts = Object.fromEntries(COUNT_BUCKET_ORDER.map((b) => [b, 0]));
  for (const row of latestRows) {
    const bucket = parseParams(row.params)[paramKey];
    if (bucket in counts) counts[bucket]++;
  }
  return counts;
}

// Mirrors Signal.bucket() (Signal.swift); older builds sent raw counts.
export function bucketCount(value) {
  if (COUNT_BUCKET_ORDER.includes(value)) return value;
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

export function tallyRawBuckets(latestRows, paramKey) {
  const counts = Object.fromEntries(COUNT_BUCKET_ORDER.map((b) => [b, 0]));
  for (const row of latestRows) {
    const bucket = bucketCount(parseParams(row.params)[paramKey]);
    if (bucket && bucket in counts) counts[bucket]++;
  }
  return counts;
}

// Only snapshots with the SubSettings marker count; a missing key on one means none changed.
export function tallySubscriptionSettings(latestRows) {
  const reporting = latestRows.map((r) => parseParams(r.params)).filter((p) => p.SubSettings != null);
  const settings = SUBSCRIPTION_SETTINGS.map(([key, label]) => {
    let users = 0;
    let atLeastFive = 0;
    for (const params of reporting) {
      const bucket = bucketCount(params[`SubSetting.${key}.Value`]);
      if (!bucket || bucket === "0") continue;
      users++;
      if (bucket !== "1-4") atLeastFive++;
    }
    return { key, label, users, atLeastFive };
  });
  return { sampleSize: reporting.length, settings };
}

// One entry per user, grouped by device type: { "iPhone": { "iPhone17,3": 4, … } }.
// The type is the coarse category every snapshot carries; the model inside it is the
// hardware identifier, or "Unknown model" for snapshots written before deviceModel shipped.
export function tallyDevices(rows) {
  const counts = {};
  for (const row of rows) {
    const params = parseParams(row.params);
    const type = params.device || "Unknown";
    const model = params.deviceModel || "Unknown model";
    if (!params.device && !params.deviceModel) continue;
    counts[type] = counts[type] || {};
    counts[type][model] = (counts[type][model] || 0) + 1;
  }
  return counts;
}

export function serverTime(at) {
  return Date.parse(String(at).replace(" ", "T") + "Z");
}

// Binned by server time, like the SQL-side trends; 'ts' only picks the latest row.
export function latestPerUserPerPeriod(rows, periodDays) {
  const periodMs = periodDays * DAY_MS;
  const periods = new Map();
  for (const row of rows) {
    if (!row.userId || row.userId === "unknown") continue;
    const at = serverTime(row.at);
    if (!Number.isFinite(at)) continue;
    const start = Math.floor(at / periodMs) * periodMs;
    const users = periods.get(start) ?? new Map();
    periods.set(start, users);
    const existing = users.get(row.userId);
    if (!existing || Number(row.ts) > Number(existing.ts)) users.set(row.userId, row);
  }
  return [...periods.keys()].sort((a, b) => a - b).map((start) => ({
    day: new Date(start).toISOString().slice(0, 10),
    rows: [...periods.get(start).values()],
  }));
}

export function platformTrend(periods) {
  return periods.map(({ day, rows }) => ({
    day,
    devices: Object.fromEntries(
      Object.entries(tallyDevices(rows)).map(([type, models]) => [type, Object.values(models).reduce((a, b) => a + b, 0)])
    ),
    os: tallyParam(rows, "os"),
  }));
}

// bool[key][i] is the 'on' count in period i.
export function settingsTrend(periods) {
  const bool = {}, values = {};
  for (const [key] of BOOL_SETTINGS) bool[key] = [];
  for (const [key] of VALUE_SETTINGS) values[key] = [];
  const totals = [];
  for (const { rows } of periods) {
    const b = tallySettings(rows), v = tallyValueSettings(rows);
    totals.push(rows.length);
    for (const key in bool) bool[key].push(b[key].on);
    for (const key in values) values[key].push(v[key].values);
  }
  return { days: periods.map((p) => p.day), totals, bool, values };
}

export function bucketTrend(rows, paramKey, name) {
  const periods = {};
  for (const row of rows) {
    if (name && row.name !== name) continue;
    const bucket = bucketCount(parseParams(row.params)[paramKey]);
    if (!bucket) continue;
    const counts = (periods[row.period] ||= {});
    counts[bucket] = (counts[bucket] || 0) + (Number(row.users) || 0);
  }
  return Object.keys(periods).sort().map((day) => ({ day, counts: periods[day] }));
}

// 'browser' Player.Start is the Play Now button, already counted as Browser.PlayNow.
export const YOUTUBE_PAGE_EVENTS = [
  'Browser.AddVideo', 'Browser.AddSubscription', 'Browser.PlayNow', 'Browser.VideoLinkIntercepted',
  'Browser.ContextMenu.Subscribe', 'Browser.ContextMenu.QueueNext', 'Browser.ContextMenu.AddToInbox',
];
export const SEARCH_USAGE_KINDS = ['search', 'youtubeMode', 'youtubePage'];

export function searchUsageKind(name) {
  if (name === 'Search.Submitted') return 'search';
  if (name === 'Search.YoutubeMode') return 'youtubeMode';
  return 'youtubePage';
}

// Rows are one per (day, user, version, event, params), so per-user sets stay in the Worker.
export function tallySearchUsage(rows, versionUsers) {
  const daily = {}, byVersion = {}, youtubeModeVia = {};
  for (const row of rows) {
    const kind = searchUsageKind(row.name);
    const day = (daily[row.day] ||= { search: new Set(), youtubeMode: new Set(), youtubePage: new Set() });
    day[kind].add(row.userId);
    const version = row.version || 'unknown';
    const v = (byVersion[version] ||= { search: new Set(), youtubeMode: new Set(), youtubePage: new Set() });
    v[kind].add(row.userId);
    if (kind === 'youtubeMode') {
      const via = parseParams(row.params).action ?? 'toggle';
      youtubeModeVia[via] = (youtubeModeVia[via] || 0) + 1;
    }
  }
  const sizes = (sets) => Object.fromEntries(SEARCH_USAGE_KINDS.map((k) => [k, sets[k].size]));
  return {
    windowDays: SEARCH_WINDOW_DAYS,
    daily: Object.keys(daily).sort().map((day) => ({ day, ...sizes(daily[day]) })),
    byVersion: versionUsers
      .map((r) => ({ version: r.version || 'unknown', users: Number(r.users) || 0 }))
      .filter((r) => byVersion[r.version])
      .map((r) => ({ ...r, ...sizes(byVersion[r.version]) })),
    youtubeModeVia,
  };
}

// Count distinct users per value of a free-form (but low-cardinality) param.
export function tallyParam(rows, paramKey) {
  const counts = {};
  for (const row of rows) {
    const value = parseParams(row.params)[paramKey];
    if (value == null || value === "") continue;
    counts[value] = (counts[value] || 0) + 1;
  }
  return counts;
}
