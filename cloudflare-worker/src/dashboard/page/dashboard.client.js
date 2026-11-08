const COLORS = { on: '#4ade80', off: '#fb923c', notTouched: '#555' };
// Ordered small -> large so bucket ranges read as a cool-to-warm gradient.
const BUCKET_COLORS = ['#1e3a8a', '#2563eb', '#3b82f6', '#60a5fa', '#38bdf8', '#22d3ee', '#34d399', '#a3e635', '#facc15'];
// Bars of these settings take the colour the value stands for, rather than a palette slot.
// themeColor: the app's ThemeColor (ThemeColor.swift), as iOS renders it in dark mode.
const VALUE_SETTING_COLORS = {
  themeColor: {
    'Red': '#ff453a', 'Orange': '#ff9f0a', 'Yellow': '#ffd60a', 'Green': '#30d158', 'Dark green': '#3a8451',
    'Mint': '#63e6e2', 'Teal': '#40c8e0', 'Blue': '#0a84ff', 'Purple': '#bf5af2', 'Black/White': '#eeeeee',
  },
};
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

function breakAtDots(name) {
  return String(name).split('.').join('.<wbr>');
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

function collapsibleCards(el, toggleBtn, cards, noun) {
  cards.forEach(function (card) { el.appendChild(card); });
  if (cards.length <= SETTINGS_COLLAPSED_COUNT) {
    toggleBtn.hidden = true;
    cards.forEach(function (card) { card.classList.remove('hidden'); });
    return;
  }
  let expanded = false;
  const sync = () => {
    cards.forEach((card, i) => card.classList.toggle('hidden', !expanded && i >= SETTINGS_COLLAPSED_COUNT));
    toggleBtn.textContent = expanded ? 'Show fewer' : 'Show all ' + cards.length + ' ' + noun;
  };
  toggleBtn.hidden = false;
  toggleBtn.onclick = () => { expanded = !expanded; sync(); };
  sync();
}

function renderSettingsGrid(el, toggleBtn, settings) {
  const totals = settings.totals;
  el.innerHTML = '';
  const cards = [];
  for (const key in totals) {
    const s = totals[key];
    const total = s.total || (s.on + s.off);
    const pct = (n) => (total ? Math.round((n / total) * 100) : 0);
    const defaultOn = !!s.default;
    const card = document.createElement('div');
    card.className = 'setting-card hidden';
    card.innerHTML =
      '<div class="setting-label">' + s.label + '</div>' +
      donutSVG(s.on, s.off, 0) +
      '<div class="legend">' +
        legendRow(COLORS.on, 'On ' + s.on + ' (' + pct(s.on) + '%)') +
        legendRow(COLORS.off, 'Off ' + s.off + ' (' + pct(s.off) + '%)') +
      '</div>' +
      '<div class="setting-meta">default <b>' + (defaultOn ? 'On' : 'Off') + '</b></div>' +
      '<div class="setting-meta">changed by <b>' + s.changed + '</b> (' + pct(s.changed) + '%)</div>';
    cards.push(card);
  }
  collapsibleCards(el, toggleBtn, cards, 'settings');
}

function renderValueSettings(el, toggleBtn, values) {
  el.innerHTML = '';
  const cards = Object.keys(values).map(function (key, index) {
    const s = values[key];
    const total = s.total || 1;
    const valueColors = VALUE_SETTING_COLORS[key];
    const rows = sortedEntries(s.values).map(function (e, i) {
      const isDefault = e[0] === s.defaultLabel;
      return {
        label: e[0] + (s.unit ? ' ' + s.unit : '') + (isDefault ? ' (default)' : ''),
        count: e[1],
        countText: e[1] + ' · ' + Math.round(e[1] / total * 100) + '%',
        color: valueColors && valueColors[e[0]] ? valueColors[e[0]]
          : isDefault ? COLORS.notTouched : BUCKET_COLORS[(index + i) % BUCKET_COLORS.length],
      };
    });
    return barChartCard(s.label, 'changed by ' + s.changed + ' (' + Math.round(s.changed / total * 100) + '%)', rows);
  });
  collapsibleCards(el, toggleBtn, cards, 'settings');
}

// Not a BOOL_SETTINGS entry on purpose: that pipeline folds users missing the key onto a
// default, but "missing" here means "no watch reported in", not "full sync off" — folding
// those in would make every non-watch user look like a "full sync off" vote.
function renderWatchFullSync(el, hintEl, counts) {
  const on = counts.On || 0;
  const off = counts.Off || 0;
  const total = on + off;
  hintEl.textContent = total
    ? 'Based on ' + total + ' watch' + (total === 1 ? '' : 'es') + ' that reported in'
    : 'No watch has reported in yet';
  const pct = (n) => (total ? Math.round((n / total) * 100) : 0);
  el.style.maxWidth = '220px';
  el.innerHTML =
    '<div class="setting-label">Full sync</div>' +
    donutSVG(on, off, 0) +
    '<div class="legend">' +
      legendRow(COLORS.on, 'On ' + on + ' (' + pct(on) + '%)') +
      legendRow(COLORS.off, 'Off ' + off + ' (' + pct(off) + '%)') +
    '</div>';
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

// One distinct hue per group (device type, OS release); a group's detail bars are
// shades of that hue, so the detail view reads as a zoom into its pie segment.
const GROUP_HUES = [210, 28, 145, 275, 0, 190, 50, 320];

function groupColor(hue, t) {
  return 'hsl(' + hue + ', 62%, ' + Math.round(40 + (t || 0) * 36) + '%)';
}

// Pie of group totals with a clickable legend: picking a group shows its individual
// entries as bars underneath ('detailEl'), picking it again hides them.
// groups: { groupLabel: { entryLabel: count } }. 'order' sorts the group labels,
// 'detailOrder' sorts one group's [label, count] entries.
function renderGroupedPie(el, detailEl, groups, order, detailOrder) {
  const labels = Object.keys(groups).sort(function (a, b) { return order(a, b, groups); });
  const totals = labels.map(function (g) {
    return Object.values(groups[g]).reduce(function (s, n) { return s + n; }, 0);
  });
  const total = totals.reduce(function (s, n) { return s + n; }, 0);
  const hues = labels.map(function (_, i) { return GROUP_HUES[i % GROUP_HUES.length]; });
  let selected = null;

  const render = function () {
    const segments = labels.map(function (g, i) { return { value: totals[i], color: groupColor(hues[i]) }; });
    const legend = labels.map(function (g, i) {
      const pct = total ? Math.round(totals[i] / total * 100) : 0;
      return '<button type="button" class="pie-pick' + (g === selected ? ' selected' : '') + '" data-group="' + i + '">' +
        '<span class="swatch" style="background:' + groupColor(hues[i]) + '"></span>' +
        '<span>' + g + ': ' + totals[i] + '&nbsp;(' + pct + '%)</span></button>';
    }).join('');
    el.innerHTML = pieSVG(segments) + '<div class="pie-legend">' + (legend || '<div class="muted">No data yet.</div>') + '</div>';
    el.querySelectorAll('.pie-pick').forEach(function (btn) {
      btn.onclick = function () {
        const g = labels[Number(btn.dataset.group)];
        selected = selected === g ? null : g;
        render();
      };
    });

    detailEl.innerHTML = '';
    detailEl.hidden = selected === null;
    if (selected === null) return;
    const gi = labels.indexOf(selected);
    const entries = Object.entries(groups[selected]).sort(detailOrder);
    const rows = entries.map(function (e, i) {
      return {
        label: e[0],
        count: e[1],
        countText: e[1] + ' · ' + Math.round(e[1] / totals[gi] * 100) + '%',
        color: groupColor(hues[gi], entries.length > 1 ? i / (entries.length - 1) : 0),
      };
    });
    detailEl.appendChild(barChartCard(selected, totals[gi] + ' users', rows));
  };
  render();
}

function byTotalDesc(a, b, groups) {
  const sum = function (g) { return Object.values(groups[g]).reduce(function (s, n) { return s + n; }, 0); };
  return sum(b) - sum(a) || a.localeCompare(b);
}

function byCountDesc(a, b) {
  return b[1] - a[1] || a[0].localeCompare(b[0]);
}

// Parses "iOS 26.1" into its platform and version numbers.
function parseOs(label) {
  const m = String(label).match(/^(.*?)\s*(\d+)(?:\.(\d+))?/);
  return {
    platform: m ? m[1].trim() : String(label),
    major: m ? parseInt(m[2], 10) : 0,
    minor: m && m[3] ? parseInt(m[3], 10) : 0,
  };
}

// Grouped by major version alone, not platform + major: iOS 26 and iPadOS 26 are the
// same OS release, and what we want to eyeball here is "who is on 26 yet", not "who
// is on an iPad" — that's the device pie's job.
function osGroup(label) {
  const p = parseOs(label);
  return p.major ? 'OS ' + p.major : String(label);
}

function byOsMajorDesc(a, b) {
  const major = function (g) { return parseInt(String(g).replace('OS ', ''), 10) || 0; };
  return major(b) - major(a) || String(a).localeCompare(String(b));
}

function renderOsPie(el, detailEl, osCounts) {
  const groups = {};
  Object.entries(osCounts).forEach(function (e) {
    const g = osGroup(e[0]);
    groups[g] = groups[g] || {};
    groups[g][e[0]] = e[1];
  });
  renderGroupedPie(el, detailEl, groups, byOsMajorDesc, function (a, b) {
    const pa = parseOs(a[0]), pb = parseOs(b[0]);
    return pa.platform.localeCompare(pb.platform) || pb.minor - pa.minor;
  });
}

// Raw hardware identifier (Signal.deviceModel, e.g. "iPhone17,3") -> marketing name.
// Kept here rather than on-device so a new device Apple ships just needs a worker
// deploy, not an app update — an unmapped identifier still renders fine, just under
// its raw id instead of a friendly name. Source: https://gist.github.com/adamawolf/3048717 (iPad17,x, the M5 iPad Pro, isn't in it yet)
const DEVICE_MODEL_NAMES = {
  'iPhone10,1': 'iPhone 8', 'iPhone10,4': 'iPhone 8', 'iPhone10,2': 'iPhone 8 Plus', 'iPhone10,5': 'iPhone 8 Plus',
  'iPhone10,3': 'iPhone X', 'iPhone10,6': 'iPhone X',
  'iPhone11,2': 'iPhone XS', 'iPhone11,4': 'iPhone XS Max', 'iPhone11,6': 'iPhone XS Max', 'iPhone11,8': 'iPhone XR',
  'iPhone12,1': 'iPhone 11', 'iPhone12,3': 'iPhone 11 Pro', 'iPhone12,5': 'iPhone 11 Pro Max', 'iPhone12,8': 'iPhone SE 2nd Gen',
  'iPhone13,1': 'iPhone 12 Mini', 'iPhone13,2': 'iPhone 12', 'iPhone13,3': 'iPhone 12 Pro', 'iPhone13,4': 'iPhone 12 Pro Max',
  'iPhone14,2': 'iPhone 13 Pro', 'iPhone14,3': 'iPhone 13 Pro Max', 'iPhone14,4': 'iPhone 13 Mini', 'iPhone14,5': 'iPhone 13',
  'iPhone14,6': 'iPhone SE 3rd Gen', 'iPhone14,7': 'iPhone 14', 'iPhone14,8': 'iPhone 14 Plus',
  'iPhone15,2': 'iPhone 14 Pro', 'iPhone15,3': 'iPhone 14 Pro Max', 'iPhone15,4': 'iPhone 15', 'iPhone15,5': 'iPhone 15 Plus',
  'iPhone16,1': 'iPhone 15 Pro', 'iPhone16,2': 'iPhone 15 Pro Max',
  'iPhone17,1': 'iPhone 16 Pro', 'iPhone17,2': 'iPhone 16 Pro Max', 'iPhone17,3': 'iPhone 16', 'iPhone17,4': 'iPhone 16 Plus', 'iPhone17,5': 'iPhone 16e',
  'iPhone18,1': 'iPhone 17 Pro', 'iPhone18,2': 'iPhone 17 Pro Max', 'iPhone18,3': 'iPhone 17', 'iPhone18,4': 'iPhone Air', 'iPhone18,5': 'iPhone 17e', 'iPhone19,4': 'iPhone Duo',
  'iPad5,3': 'iPad Air 2', 'iPad5,4': 'iPad Air 2', 'iPad5,1': 'iPad mini 4', 'iPad5,2': 'iPad mini 4',
  'iPad6,3': 'iPad Pro 9.7-inch', 'iPad6,4': 'iPad Pro 9.7-inch', 'iPad6,7': 'iPad Pro 12.9-inch', 'iPad6,8': 'iPad Pro 12.9-inch',
  'iPad6,11': 'iPad 5th Gen', 'iPad6,12': 'iPad 5th Gen',
  'iPad7,1': 'iPad Pro 12.9-inch 2nd Gen', 'iPad7,2': 'iPad Pro 12.9-inch 2nd Gen',
  'iPad7,3': 'iPad Pro 10.5-inch', 'iPad7,4': 'iPad Pro 10.5-inch',
  'iPad7,5': 'iPad 6th Gen', 'iPad7,6': 'iPad 6th Gen', 'iPad7,11': 'iPad 7th Gen', 'iPad7,12': 'iPad 7th Gen',
  'iPad8,1': 'iPad Pro 11-inch', 'iPad8,2': 'iPad Pro 11-inch', 'iPad8,3': 'iPad Pro 11-inch', 'iPad8,4': 'iPad Pro 11-inch',
  'iPad8,5': 'iPad Pro 12.9-inch 3rd Gen', 'iPad8,6': 'iPad Pro 12.9-inch 3rd Gen', 'iPad8,7': 'iPad Pro 12.9-inch 3rd Gen', 'iPad8,8': 'iPad Pro 12.9-inch 3rd Gen',
  'iPad8,9': 'iPad Pro 11-inch 2nd Gen', 'iPad8,10': 'iPad Pro 11-inch 2nd Gen',
  'iPad8,11': 'iPad Pro 12.9-inch 4th Gen', 'iPad8,12': 'iPad Pro 12.9-inch 4th Gen',
  'iPad11,1': 'iPad mini 5th Gen', 'iPad11,2': 'iPad mini 5th Gen', 'iPad11,3': 'iPad Air 3rd Gen', 'iPad11,4': 'iPad Air 3rd Gen',
  'iPad11,6': 'iPad 8th Gen', 'iPad11,7': 'iPad 8th Gen', 'iPad12,1': 'iPad 9th Gen', 'iPad12,2': 'iPad 9th Gen',
  'iPad14,1': 'iPad mini 6th Gen', 'iPad14,2': 'iPad mini 6th Gen', 'iPad13,1': 'iPad Air 4th Gen', 'iPad13,2': 'iPad Air 4th Gen',
  'iPad13,4': 'iPad Pro 11-inch 3rd Gen', 'iPad13,5': 'iPad Pro 11-inch 3rd Gen', 'iPad13,6': 'iPad Pro 11-inch 3rd Gen', 'iPad13,7': 'iPad Pro 11-inch 3rd Gen',
  'iPad13,8': 'iPad Pro 12.9-inch 5th Gen', 'iPad13,9': 'iPad Pro 12.9-inch 5th Gen', 'iPad13,10': 'iPad Pro 12.9-inch 5th Gen', 'iPad13,11': 'iPad Pro 12.9-inch 5th Gen',
  'iPad13,16': 'iPad Air 5th Gen', 'iPad13,17': 'iPad Air 5th Gen', 'iPad13,18': 'iPad 10th Gen', 'iPad13,19': 'iPad 10th Gen',
  'iPad14,3': 'iPad Pro 11-inch 4th Gen', 'iPad14,4': 'iPad Pro 11-inch 4th Gen', 'iPad14,5': 'iPad Pro 12.9-inch 6th Gen', 'iPad14,6': 'iPad Pro 12.9-inch 6th Gen',
  'iPad14,8': 'iPad Air 11-inch 6th Gen', 'iPad14,9': 'iPad Air 11-inch 6th Gen', 'iPad14,10': 'iPad Air 13-inch 6th Gen', 'iPad14,11': 'iPad Air 13-inch 6th Gen',
  'iPad15,3': 'iPad Air 11-inch 7th Gen', 'iPad15,4': 'iPad Air 11-inch 7th Gen', 'iPad15,5': 'iPad Air 13-inch 7th Gen', 'iPad15,6': 'iPad Air 13-inch 7th Gen',
  'iPad15,7': 'iPad 11th Gen', 'iPad15,8': 'iPad 11th Gen',
  'iPad16,1': 'iPad mini 7th Gen', 'iPad16,2': 'iPad mini 7th Gen',
  'iPad16,3': 'iPad Pro 11-inch 5th Gen', 'iPad16,4': 'iPad Pro 11-inch 5th Gen', 'iPad16,5': 'iPad Pro 12.9-inch 7th Gen', 'iPad16,6': 'iPad Pro 12.9-inch 7th Gen',
  'iPad16,8': 'iPad Air 11-inch 8th Gen', 'iPad16,9': 'iPad Air 11-inch 8th Gen', 'iPad16,10': 'iPad Air 13-inch 8th Gen', 'iPad16,11': 'iPad Air 13-inch 8th Gen',
  'iPad17,1': 'iPad Pro 11-inch 6th Gen', 'iPad17,2': 'iPad Pro 11-inch 6th Gen', 'iPad17,3': 'iPad Pro 13-inch 7th Gen', 'iPad17,4': 'iPad Pro 13-inch 7th Gen',
  'RealityDevice14,1': 'Vision Pro',
  'i386': 'Simulator', 'x86_64': 'Simulator', 'arm64': 'Simulator',
};

// groups: { device type: { raw hardware identifier: count } } — see tallyDevices.
function renderDevicePie(el, detailEl, deviceTypes) {
  const groups = {};
  Object.keys(deviceTypes).forEach(function (type) {
    groups[type] = {};
    Object.entries(deviceTypes[type]).forEach(function (e) {
      const name = DEVICE_MODEL_NAMES[e[0]] || e[0];
      groups[type][name] = (groups[type][name] || 0) + e[1];
    });
  });
  renderGroupedPie(el, detailEl, groups, byTotalDesc, byCountDesc);
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
function lineChartSVG(series, valueKey, color, limit, pxWidth) {
  const W = pxWidth || 640, H = Math.max(140, Math.round(W * 0.28)), padL = 34, padR = 12, padT = 12, padB = 22;
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
      '<text x="' + (padL - 4) + '" y="' + (gy + 3).toFixed(1) + '" text-anchor="end" font-size="10" fill="#777">' + fmtNum(v) + '</text>';
  });
  let xlabels = '';
  const idxs = pts.length === 1 ? [0] : [0, Math.floor((pts.length - 1) / 2), pts.length - 1];
  idxs.forEach(function (i, k) {
    const anchor = k === 0 ? 'start' : (k === idxs.length - 1 ? 'end' : 'middle');
    xlabels += '<text x="' + x(i).toFixed(1) + '" y="' + (H - 6) + '" text-anchor="' + anchor + '" font-size="10" fill="#777">' + dayLabel(pts[i].label) + '</text>';
  });
  const lastI = pts.length - 1;
  const dot = '<circle cx="' + x(lastI).toFixed(1) + '" cy="' + y(pts[lastI].value).toFixed(1) + '" r="3" fill="' + color + '"/>';
  let limitLine = '';
  if (limit) {
    const ly = y(limit);
    limitLine = '<line x1="' + padL + '" y1="' + ly.toFixed(1) + '" x2="' + (W - padR) + '" y2="' + ly.toFixed(1) +
      '" stroke="#f87171" stroke-width="1" stroke-dasharray="4 3"/>' +
      '<text x="' + (W - padR) + '" y="' + (ly - 4).toFixed(1) + '" text-anchor="end" font-size="10" fill="#f87171">free limit ' + fmtNum(limit) + '/day</text>';
  }
  return '<svg viewBox="0 0 ' + W + ' ' + H + '" xmlns="http://www.w3.org/2000/svg">' +
    grid +
    '<path d="' + area + '" fill="' + color + '" fill-opacity="0.15"/>' +
    '<path d="' + line + '" fill="none" stroke="' + color + '" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"/>' +
    limitLine + dot + xlabels + '</svg>';
}

function renderLineChart(el, series, valueKey, color, limit, per) {
  per = per || 'day';
  series = series || [];
  const values = series.map(function (r) { return Number(r[valueKey]) || 0; });
  const total = values.reduce(function (a, b) { return a + b; }, 0);
  const avg = values.length ? total / values.length : 0;
  const peak = values.length ? Math.max.apply(null, values) : 0;
  // With a limit, the useful right-hand stat is how close the busiest day came to the cap.
  const right = limit
    ? 'peak <b>' + fmtNum(peak) + '</b> · <b>' + Math.round(peak / limit * 100) + '%</b> of limit'
    : 'peak <b>' + fmtNum(peak) + '</b>';
  el.innerHTML = '<div class="chart-meta"><span>avg <b>' + fmtNum(avg) + '</b>/' + per + '</span><span>' + right + '</span></div>' +
    lineChartSVG(series, valueKey, color, limit, chartWidth(el));
}

const FUNNELS = [
  { title: 'Premium conversion', steps: [
    ['Premium.ShowPopup', 'Saw premium popup'],
    ['Premium.LearnMore', 'Tapped learn more'],
    ['Premium.Subscribe', 'Subscribed'],
  ]},
];

// Not a funnel: most users skip the first step.
const ACTIVATION_EVENTS = [
  ['Onboarding.BrowseYoutube', 'Empty-queue browse'],
  ['Browser.AddSubscription', 'Added a subscription'],
  ['Player.WatchedVideo', 'Watched a video'],
];

// The first-launch flow, in the order Signal.onboardingStep emits it.
const ONBOARDING_STEPS = [
  ['started', 'Reached onboarding'],
  ['channels', 'Got past channel picking'],
  ['finished', 'Landed in the inbox'],
];

// Counts events, not users: each step fires at most once per install.
function renderOnboardingFunnel(el, paramEvents) {
  const totals = aggregateParam(paramEvents || [], 'Onboarding.Step', 'step');
  const counts = ONBOARDING_STEPS.map(function (s) { return totals[s[0]] || 0; });
  const top = Math.max(1, counts[0]);
  let rows = '';
  ONBOARDING_STEPS.forEach(function (s, i) {
    const c = counts[i];
    const widthPct = Math.max(2, Math.min(100, c / top * 100));
    const conv = i === 0
      ? (c + ' installs')
      : (counts[i - 1] ? Math.round(c / counts[i - 1] * 100) + '% of previous step' : '—');
    rows += '<div class="funnel-row"><span class="fill" style="width:' + widthPct + '%"></span>' +
      '<span class="txt">' + s[1] + ' — ' + c + '</span></div>' +
      '<div class="funnel-conv">' + conv + '</div>';
  });
  const card = document.createElement('div');
  card.className = 'card';
  card.innerHTML = '<div class="chart-meta"><span><b>First launch</b></span></div><div class="funnel">' + rows + '</div>';
  el.appendChild(card);
}

function renderGenerationResults(el, paramEvents) {
  const byKind = {};
  (paramEvents || []).forEach(function (r) {
    if (r.name !== 'Generation.Result') return;
    const kind = r.params.kind || 'unknown';
    const outcome = r.params.outcome || 'unknown';
    byKind[kind] = byKind[kind] || { total: 0, outcomes: {} };
    byKind[kind].total += r.count;
    byKind[kind].outcomes[outcome] = (byKind[kind].outcomes[outcome] || 0) + r.count;
  });
  const kinds = Object.keys(byKind);
  if (!kinds.length) {
    el.innerHTML = '<div class="card"><div class="hint">No generations reported yet.</div></div>';
    return;
  }
  el.innerHTML = '';
  kinds.forEach(function (kind, gi) {
    const entry = byKind[kind];
    const rate = Math.round((entry.outcomes.success || 0) / Math.max(1, entry.total) * 100);
    const rows = sortedEntries(entry.outcomes).map(function (e, i) {
      const color = e[0] === 'success' ? COLORS.on : BUCKET_COLORS[(gi * 3 + i) % BUCKET_COLORS.length];
      return { label: e[0], count: e[1], color: color };
    });
    el.appendChild(barChartCard(kind, rate + '% succeeded', rows));
  });
}

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
  const rows = ACTIVATION_EVENTS.map(function (e, i) {
    return { label: e[1], count: usersByEvent[e[0]] || 0, color: BUCKET_COLORS[(2 + i) % BUCKET_COLORS.length] };
  });
  el.appendChild(barChartCard('Activation (existing users)', 'users, not a sequence', rows));
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

const SEARCH_USAGE_SERIES = [
  ['search', 'Search', '#3b82f6'],
  ['youtubeMode', 'YouTube mode', '#f87171'],
  ['youtubePage', 'YouTube page', '#fbbf24'],
];

const DENSE_SERIES_POINTS = 24;

function multiLineChartSVG(series, lines, pxWidth, opts) {
  opts = opts || {};
  const fmt = opts.formatY || fmtNum;
  if (series.length === 0) return '<div class="hint">No data yet.</div>';
  const W = pxWidth || 640, H = Math.max(140, Math.round(W * 0.28)), padL = 34, padR = 12, padT = 12, padB = 22;
  const max = Math.max(1, Math.max.apply(null, series.flatMap(function (row) {
    return lines.map(function (l) { return Number(row[l[0]]) || 0; });
  })));
  const innerW = W - padL - padR, innerH = H - padT - padB;
  const x = function (i) { return padL + (series.length === 1 ? innerW / 2 : innerW * i / (series.length - 1)); };
  const y = function (v) { return padT + innerH * (1 - v / max); };
  let svg = '';
  [0, max / 2, max].forEach(function (v) {
    const gy = y(v);
    svg += '<line x1="' + padL + '" y1="' + gy.toFixed(1) + '" x2="' + (W - padR) + '" y2="' + gy.toFixed(1) + '" stroke="#2a2a2a"/>' +
      '<text x="' + (padL - 4) + '" y="' + (gy + 3).toFixed(1) + '" text-anchor="end" font-size="10" fill="#777">' + fmt(v) + '</text>';
  });
  lines.forEach(function (l) {
    let d = '';
    series.forEach(function (row, i) { d += (i === 0 ? 'M' : 'L') + x(i).toFixed(1) + ' ' + y(Number(row[l[0]]) || 0).toFixed(1) + ' '; });
    svg += '<path d="' + d + '" fill="none" stroke="' + l[2] + '" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"/>';
    if (opts.pointTitle) {
      const dot = series.length <= DENSE_SERIES_POINTS ? 'r="2.5"' : 'r="4" fill-opacity="0"';
      series.forEach(function (row, i) {
        svg += '<circle cx="' + x(i).toFixed(1) + '" cy="' + y(Number(row[l[0]]) || 0).toFixed(1) + '" ' + dot + ' fill="' + l[2] + '">' +
          '<title>' + opts.pointTitle(row, l) + '</title></circle>';
      });
    }
  });
  const idxs = series.length === 1 ? [0] : [0, Math.floor((series.length - 1) / 2), series.length - 1];
  idxs.forEach(function (i, k) {
    const anchor = k === 0 ? 'start' : (k === idxs.length - 1 ? 'end' : 'middle');
    svg += '<text x="' + x(i).toFixed(1) + '" y="' + (H - 6) + '" text-anchor="' + anchor + '" font-size="10" fill="#777">' + dayLabel(series[i].day) + '</text>';
  });
  return '<svg viewBox="0 0 ' + W + ' ' + H + '" xmlns="http://www.w3.org/2000/svg">' + svg + '</svg>';
}

const TREND_COLORS = ['#3b82f6', '#4ade80', '#fbbf24', '#f87171', '#a78bfa', '#22d3ee', '#fb923c', '#f472b6'];
const OTHER_COLOR = '#666';
const TREND_MAX_SERIES = 7;
const MIN_RANKING_SAMPLE = 5;

function esc(value) {
  return String(value).replace(/[&<>"']/g, function (c) {
    return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
  });
}

function truncatedNote(truncated) {
  return truncated ? ' Hit the row limit: the oldest periods are missing users.' : '';
}

function chartWidth(el) {
  return el.clientWidth ? Math.max(280, el.clientWidth - 32) : 0;
}

function readViewPref(key) {
  try { return localStorage.getItem('dashboardView.' + key); } catch (e) { return null; }
}
function writeViewPref(key, value) {
  try { localStorage.setItem('dashboardView.' + key, value); } catch (e) {}
}

// renderOnce waits until its view is visible, so charts measure their real width.
function setupViewSwitch(key, switchEl, views, defaultView) {
  let current = readViewPref(key);
  if (!views.some(function (v) { return v.id === current; })) current = defaultView || views[0].id;
  const rendered = {};
  const apply = function () {
    switchEl.innerHTML = views.map(function (v) {
      return '<button type="button" data-view="' + v.id + '"' + (v.id === current ? ' class="selected"' : '') + '>' + v.label + '</button>';
    }).join('');
    switchEl.querySelectorAll('button').forEach(function (btn) {
      btn.onclick = function () {
        current = btn.dataset.view;
        writeViewPref(key, current);
        apply();
      };
    });
    const view = views.find(function (v) { return v.id === current; });
    views.forEach(function (v) { v.elements.forEach(function (el) { el.hidden = true; }); });
    view.elements.forEach(function (el) { el.hidden = false; });
    if (view.onShow) view.onShow();
    if (view.renderOnce && !rendered[view.id]) {
      rendered[view.id] = true;
      view.renderOnce();
    }
  };
  apply();
}

function pointTotal(point) {
  return Object.values(point.counts).reduce(function (a, b) { return a + b; }, 0);
}

// Ranked by peak share so a build just rolling out still gets a line.
function foldTrend(points, maxSeries, order) {
  const ranked = points.filter(function (p) { return pointTotal(p) >= MIN_RANKING_SAMPLE; });
  const peak = {};
  (ranked.length ? ranked : points).forEach(function (p) {
    const total = pointTotal(p) || 1;
    Object.keys(p.counts).forEach(function (k) { peak[k] = Math.max(peak[k] || 0, p.counts[k] / total); });
  });
  points.forEach(function (p) { Object.keys(p.counts).forEach(function (k) { peak[k] = peak[k] || 0; }); });
  const byPeak = Object.keys(peak).sort(function (a, b) { return peak[b] - peak[a]; });
  const keep = byPeak.slice(0, maxSeries).sort(order || function (a, b) { return peak[b] - peak[a]; });
  const kept = {};
  keep.forEach(function (k) { kept[k] = true; });
  const folded = points.map(function (p) {
    const counts = {};
    Object.keys(p.counts).forEach(function (k) {
      const target = kept[k] ? k : 'Other';
      counts[target] = (counts[target] || 0) + p.counts[k];
    });
    return { day: p.day, counts: counts };
  });
  const series = keep.map(function (k, i) { return { key: k, label: k, color: TREND_COLORS[i % TREND_COLORS.length] }; });
  if (byPeak.length > keep.length) series.push({ key: 'Other', label: 'Other', color: OTHER_COLOR });
  return { points: folded, series: series };
}

// Shares, not counts, so a partial latest period doesn't read as a drop.
function renderTrend(el, title, points, series, width) {
  const off = {};
  const lineKey = function (s) { return 's:' + s.key; };
  const rows = points.map(function (p) {
    const total = pointTotal(p);
    const row = { day: p.day, total: total, n: {} };
    series.forEach(function (s) {
      const n = p.counts[s.key] || 0;
      row.n[s.key] = n;
      row[lineKey(s)] = total ? n / total * 100 : 0;
    });
    return row;
  });
  const pct = function (v) { return Math.round(v) + '%'; };
  const draw = function () {
    const last = rows[rows.length - 1];
    const lines = series.filter(function (s) { return !off[s.key]; }).map(function (s) { return [lineKey(s), s, s.color]; });
    const legend = series.map(function (s, i) {
      return '<button type="button" class="pie-pick' + (off[s.key] ? ' off' : '') + '" data-i="' + i + '">' +
        '<span class="swatch" style="background:' + s.color + '"></span>' +
        '<span>' + esc(s.label) + (last ? ' · ' + pct(last[lineKey(s)]) : '') + '</span></button>';
    }).join('');
    el.innerHTML = '<div class="chart-meta"><span><b>' + esc(title) + '</b></span>' +
      (last ? '<span>latest <b>' + last.total + '</b> users</span>' : '') + '</div>' +
      multiLineChartSVG(rows, lines, width || chartWidth(el), {
        formatY: pct,
        pointTitle: function (row, line) {
          const s = line[1];
          return esc(s.label + ' · ' + dayLabel(row.day) + ': ' + pct(row[line[0]]) + ' (' + row.n[s.key] + ' of ' + row.total + ')');
        },
      }) +
      (series.length ? '<div class="pie-legend trend-legend">' + legend + '</div>' : '');
    el.querySelectorAll('.pie-pick').forEach(function (btn) {
      btn.onclick = function () {
        const key = series[Number(btn.dataset.i)].key;
        off[key] = !off[key];
        draw();
      };
    });
  };
  draw();
}

function compareVersionsDesc(a, b) {
  const pa = String(a).split(/[^0-9]+/).filter(Boolean).map(Number);
  const pb = String(b).split(/[^0-9]+/).filter(Boolean).map(Number);
  for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
    const d = (pb[i] || 0) - (pa[i] || 0);
    if (d) return d;
  }
  return String(a).localeCompare(String(b));
}

function renderVersionTrend(el, trend) {
  const byDay = {};
  (trend.rows || []).forEach(function (r) {
    const counts = (byDay[r.day] = byDay[r.day] || {});
    counts[r.version] = (counts[r.version] || 0) + r.users;
  });
  const points = Object.keys(byDay).sort().map(function (day) { return { day: day, counts: byDay[day] }; });
  const folded = foldTrend(points, TREND_MAX_SERIES, compareVersionsDesc);
  renderTrend(el, 'Share of daily active users', folded.points, folded.series);
}

function renderDeviceTrend(el, trend) {
  const points = (trend || []).map(function (p) { return { day: p.day, counts: p.devices || {} }; });
  const folded = foldTrend(points, TREND_MAX_SERIES);
  renderTrend(el, 'Device', folded.points, folded.series);
}

function renderOsTrend(el, trend) {
  const points = (trend || []).map(function (p) {
    const counts = {};
    Object.entries(p.os || {}).forEach(function (e) {
      const g = osGroup(e[0]);
      counts[g] = (counts[g] || 0) + e[1];
    });
    return { day: p.day, counts: counts };
  });
  const folded = foldTrend(points, TREND_MAX_SERIES, byOsMajorDesc);
  renderTrend(el, 'OS version', folded.points, folded.series);
}

function renderBucketTrend(el, title, trend, bucketOrder) {
  const seen = {};
  (trend || []).forEach(function (p) { Object.keys(p.counts).forEach(function (k) { if (p.counts[k]) seen[k] = true; }); });
  const series = bucketOrder.map(function (b, i) { return { key: b, label: b, color: BUCKET_COLORS[i % BUCKET_COLORS.length] }; })
    .filter(function (s) { return seen[s.key]; });
  renderTrend(el, title, trend || [], series);
}

// Fixed 0-100% axis so cards side by side compare.
function sparklineSVG(values, color) {
  const W = 160, H = 44, pad = 3;
  const pts = [];
  values.forEach(function (v, i) { if (v != null) pts.push([i, v]); });
  if (!pts.length) return '<div class="hint">No data yet.</div>';
  const x = function (i) { return pad + (values.length === 1 ? (W - 2 * pad) / 2 : (W - 2 * pad) * i / (values.length - 1)); };
  const y = function (v) { return pad + (H - 2 * pad) * (1 - v / 100); };
  let d = '';
  pts.forEach(function (p, k) { d += (k === 0 ? 'M' : 'L') + x(p[0]).toFixed(1) + ' ' + y(p[1]).toFixed(1) + ' '; });
  const last = pts[pts.length - 1];
  return '<svg class="sparkline" viewBox="0 0 ' + W + ' ' + H + '" preserveAspectRatio="none" xmlns="http://www.w3.org/2000/svg">' +
    '<line x1="0" y1="' + y(50).toFixed(1) + '" x2="' + W + '" y2="' + y(50).toFixed(1) + '" stroke="#2a2a2a" stroke-dasharray="2 3"/>' +
    '<path d="' + d + '" fill="none" stroke="' + color + '" stroke-width="2" stroke-linejoin="round" stroke-linecap="round" vector-effect="non-scaling-stroke"/>' +
    '<circle cx="' + x(last[0]).toFixed(1) + '" cy="' + y(last[1]).toFixed(1) + '" r="2.5" fill="' + color + '"/></svg>';
}

function renderSettingsTrendGrid(el, toggleBtn, settings) {
  const trend = settings.trend || { days: [], totals: [], bool: {} };
  el.innerHTML = '';
  const cards = Object.keys(trend.bool).map(function (key) {
    const s = settings.totals[key] || { label: key, default: false };
    const shares = trend.bool[key].map(function (on, i) { return trend.totals[i] ? on / trend.totals[i] * 100 : null; });
    const known = shares.filter(function (v) { return v != null; });
    const first = known.length ? known[0] : 0, last = known.length ? known[known.length - 1] : 0;
    const delta = Math.round(last - first);
    const card = document.createElement('div');
    card.className = 'setting-card hidden';
    card.title = trend.days.map(function (day, i) {
      return dayLabel(day) + ': ' + (shares[i] == null ? '—' : Math.round(shares[i]) + '% on (' + trend.bool[key][i] + ' of ' + trend.totals[i] + ')');
    }).join('\n');
    card.innerHTML =
      '<div class="setting-label">' + s.label + '</div>' +
      '<div class="setting-now">' + Math.round(last) + '% on</div>' +
      sparklineSVG(shares, COLORS.on) +
      '<div class="setting-meta">' + Math.round(first) + '% → ' + Math.round(last) + '% ' +
        '<b class="' + (delta > 0 ? 'up' : delta < 0 ? 'down' : '') + '">' + (delta > 0 ? '+' : '') + delta + '</b></div>' +
      '<div class="setting-meta">default <b>' + (s.default ? 'On' : 'Off') + '</b></div>';
    return { card: card, move: Math.abs(last - first) };
  });
  cards.sort(function (a, b) { return b.move - a.move; });
  collapsibleCards(el, toggleBtn, cards.map(function (c) { return c.card; }), 'settings');
}

function renderValueSettingsTrend(el, toggleBtn, settings) {
  const trend = settings.trend || { days: [], values: {} };
  el.innerHTML = '';
  const keys = Object.keys(trend.values);
  const cards = keys.map(function () {
    const card = document.createElement('div');
    card.className = 'card hidden';
    return card;
  });
  collapsibleCards(el, toggleBtn, cards, 'settings');
  // Hidden cards measure 0.
  const width = cards.length ? chartWidth(cards[0]) : 0;
  keys.forEach(function (key, k) {
    const s = settings.values[key] || { label: key, defaultLabel: '', unit: '' };
    const points = trend.days.map(function (day, i) { return { day: day, counts: trend.values[key][i] || {} }; });
    const folded = foldTrend(points, TREND_MAX_SERIES);
    const valueColors = VALUE_SETTING_COLORS[key];
    const series = folded.series.map(function (sr) {
      const isDefault = sr.key === s.defaultLabel;
      return {
        key: sr.key,
        label: sr.key + (s.unit && sr.key !== 'Other' ? ' ' + s.unit : '') + (isDefault ? ' (default)' : ''),
        color: valueColors && valueColors[sr.key] ? valueColors[sr.key] : isDefault ? COLORS.notTouched : sr.color,
      };
    });
    renderTrend(cards[k], s.label, folded.points, series, width);
  });
}

function renderSearchUsage(trendEl, breakdownEl, usage) {
  const legend = SEARCH_USAGE_SERIES.map(function (l) { return legendRow(l[2], l[1]); }).join('');
  trendEl.innerHTML = '<div class="chart-meta"><span><b>People per day</b></span></div>' +
    multiLineChartSVG(usage.daily || [], SEARCH_USAGE_SERIES, chartWidth(trendEl)) +
    '<div class="legend">' + legend + '</div>';

  breakdownEl.innerHTML = '';
  (usage.byVersion || []).forEach(function (v) {
    const rows = SEARCH_USAGE_SERIES.map(function (l) {
      const share = v.users ? v[l[0]] / v.users : 0;
      return { label: l[1], count: share, color: l[2], countText: Math.round(share * 100) + '% · ' + v[l[0]] };
    });
    breakdownEl.appendChild(barChartCard(v.version, v.users + ' active users', rows));
  });
  breakdownEl.appendChild(barCard('YouTube mode — turned on via (user-days)', usage.youtubeModeVia || {}, 1));
}

function renderCompare(el, countsByEvent) {
  el.innerHTML = '';
  COMPARE_GROUPS.forEach(function (g, gi) {
    const rows = g.events.map(function (e, i) {
      return { label: e[1], count: countsByEvent[e[0]] || 0, color: BUCKET_COLORS[(gi * 3 + i) % BUCKET_COLORS.length] };
    });
    el.appendChild(barChartCard(g.title, null, rows));
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
  const rows = sortedEntries(totals).map(function (e, i) {
    return { label: e[0], count: e[1], color: BUCKET_COLORS[(gi * 3 + i) % BUCKET_COLORS.length] };
  });
  return barChartCard(title, null, rows);
}

function sortedEntries(totals) {
  return Object.entries(totals).sort(function (a, b) { return b[1] - a[1]; });
}

// rows: [{ label, count, color, countText? }]
function barRowsHTML(rows) {
  const max = Math.max(1, Math.max.apply(null, rows.map(function (r) { return r.count; })));
  let html = '';
  rows.forEach(function (r) {
    html += '<div class="cmp-row"><span class="cmp-label">' + r.label + '</span>' +
      '<span class="cmp-track"><span class="cmp-fill" style="width:' + (r.count / max * 100) + '%;background:' + r.color + '"></span></span>' +
      '<span class="cmp-count">' + (r.countText || r.count) + '</span></div>';
  });
  if (!rows.length) html = '<div class="hint">No data yet.</div>';
  return '<div class="cmp-chart">' + html + '</div>';
}

function barChartCard(title, meta, rows) {
  const card = document.createElement('div');
  card.className = 'card';
  card.innerHTML = '<div class="chart-meta"><span><b>' + title + '</b></span>' +
    (meta ? '<span>' + meta + '</span>' : '') + '</div>' + barRowsHTML(rows);
  return card;
}

function renderBucketBars(el, buckets) {
  const entries = Object.entries(buckets);
  const total = entries.reduce(function (sum, e) { return sum + e[1]; }, 0);
  el.innerHTML = barRowsHTML(total ? entries.map(function (e) {
    return {
      label: e[0],
      count: e[1],
      countText: e[1] + ' · ' + Math.round(e[1] / total * 100) + '%',
      color: BUCKET_COLORS[2],
    };
  }) : []);
}

function renderSubscriptionSettings(el, hintEl, sub, windowDays) {
  sub = sub || { sampleSize: 0, settings: [] };
  const total = sub.sampleSize;
  hintEl.textContent = 'Users who changed each setting on at least one subscription, of ' + total +
    ' users on a build that reports them, active in the last ' + windowDays +
    ' days. "5+" is how many of them did so on five or more subscriptions.';
  const rows = sub.settings.slice().sort(function (a, b) { return b.users - a.users; });
  el.innerHTML = barRowsHTML(total ? rows.map(function (s) {
    return {
      label: s.label,
      count: s.users,
      countText: s.users + ' · ' + Math.round(s.users / total * 100) + '% · 5+: ' + s.atLeastFive,
      color: BUCKET_COLORS[2],
    };
  }) : []);
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
  el.appendChild(barCard('Media played — video vs podcast', aggregateParam(paramEvents, 'Player.Media', 'action'), 4));
  const channelStep = paramEvents.filter(function (r) { return r.params.step === 'channels'; });
  el.appendChild(barCard('Onboarding — channels picked', aggregateParam(channelStep, 'Onboarding.Step', 'selected'), 5));
  el.appendChild(barCard('Onboarding — used channel search', aggregateParam(channelStep, 'Onboarding.Step', 'usedSearch'), 6));
  el.appendChild(barCard('Subscribed — by source', aggregateParam(paramEvents, 'Subscription.Added', 'source'), 3));
  el.appendChild(barCard('Premium popup — by feature', aggregateParam(paramEvents, 'Premium.ShowPopup', 'feature'), 4));
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
    tr.innerHTML = '<td>' + breakAtDots(r.name) + '</td>' +
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
    tr.innerHTML = '<td>' + breakAtDots(r.id) + '</td><td class="num">' + r.count + '</td>';
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
    tr.innerHTML = `<td>${breakAtDots(row.name)}</td><td>${row.params}</td><td>${channel}</td><td title="${tr.title}">${when}</td>`;
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

  if (data.failures && data.failures.length) {
    const partial = document.getElementById('partial');
    partial.innerHTML = 'Some data could not be loaded; the sections below it are empty, not zero:' +
      '<ul>' + data.failures.map(function (f) {
        return '<li>' + String(f).replace(/[<>&]/g, '') + '</li>';
      }).join('') + '</ul>';
    partial.hidden = false;
  }

  const activeEl = document.getElementById('activeUsers');
  const activeLabels = { daily: 'DAU (24h)', weekly: 'WAU (7d)', monthly: 'MAU (30d)' };
  for (const key in activeLabels) {
    const card = document.createElement('div');
    card.className = 'stat-card';
    card.innerHTML = '<div class="value">' + (data.activeUsers[key] ?? 0) + '</div><div class="label">' + activeLabels[key] + '</div>';
    activeEl.appendChild(card);
  }

  const win = '(last ' + data.trendWindowDays + ' days)';
  document.getElementById('eventWindow').textContent = win;
  const auTrend = data.activeUsersTrend || {};
  document.getElementById('dauWindow').textContent = '(last ' + auTrend.windowDays + ' days)';
  const dauEl = document.getElementById('dauTrend');
  const dauHint = document.getElementById('dauHint');
  const auView = function (id, label, hint) {
    return { id: id, label: label, elements: [dauEl], onShow: function () {
      dauHint.textContent = hint;
      renderLineChart(dauEl, auTrend[id], 'users', '#4ade80', 0, label.toLowerCase());
    } };
  };
  setupViewSwitch('activeUsers', document.getElementById('dauSwitch'), [
    auView('daily', 'Day', 'Distinct people active each day.'),
    auView('weekly', 'Week', 'Distinct people active in each 7-day period. The first and latest period are partial.'),
    auView('monthly', 'Month', 'Distinct people active in each calendar month. The first and latest month are partial.'),
  ]);

  document.getElementById('platformHint').textContent =
    'Now: based on ' + data.platform.sampleSize + ' users active in the last ' + data.platform.windowDays + ' days. ' +
    'Over time: each point is the users who sent a settings snapshot in that ' + data.platform.trendPeriodDays +
    '-day period (one per user), over the last ' + data.platform.trendWindowDays + ' days; the latest period is still filling in.' +
    truncatedNote(data.platform.trendTruncated);
  renderDevicePie(document.getElementById('devicePie'), document.getElementById('deviceDetail'), data.platform.devices);
  renderOsPie(document.getElementById('osPie'), document.getElementById('osDetail'), data.platform.os);
  const platform = data.platform;
  setupViewSwitch('platform', document.getElementById('platformSwitch'), [
    { id: 'now', label: 'Now', elements: [document.getElementById('platformNow')] },
    { id: 'trend', label: 'Over time', elements: [document.getElementById('platformTrend')], renderOnce: function () {
      renderDeviceTrend(document.getElementById('deviceTrend'), platform.trend);
      renderOsTrend(document.getElementById('osTrend'), platform.trend);
    } },
  ]);
  renderWatchFullSync(
    document.getElementById('watchFullSyncCard'),
    document.getElementById('watchFullSyncHint'),
    data.platform.watchFullSync
  );

  const versionTotals = {};
  (data.versions || []).forEach(function (r) { versionTotals[r.version] = r.users; });
  const versionTrend = data.versionsTrend || {};
  const versionHint = document.getElementById('versionHint');
  setupViewSwitch('version', document.getElementById('versionSwitch'), [
    { id: 'now', label: 'Now', elements: [document.getElementById('versionPie')], onShow: function () {
      document.getElementById('versionWindow').textContent = win;
      versionHint.textContent = 'Distinct users per build. Versions people are still on, not versions they last reported a snapshot from.';
    } },
    { id: 'trend', label: 'Over time', elements: [document.getElementById('versionTrend')], renderOnce: function () {
      renderVersionTrend(document.getElementById('versionTrend'), versionTrend);
    }, onShow: function () {
      document.getElementById('versionWindow').textContent = '(last ' + versionTrend.windowDays + ' days)';
      versionHint.textContent = 'Each build’s share of the people active that day — how fast a release rolls out and an old one drains. ' +
        'Smaller builds are folded into Other; click a legend entry to hide its line.';
    } },
  ], 'trend');
  renderPie(document.getElementById('versionPie'), versionTotals);

  const countsByEvent = {}, usersByEvent = {};
  (data.counts || []).forEach(function (r) {
    countsByEvent[r.name] = Number(r.count) || 0;
    usersByEvent[r.name] = Number(r.users) || 0;
  });

  document.getElementById('engagementWindow').textContent = win;
  renderEngagement(document.querySelector('#engagement tbody'), data.counts || [], data.activeUsers.weekly);

  renderLineChart(document.getElementById('eventTrend'), data.eventTrend, 'events', '#3b82f6');

  var writes = data.writes || {};
  document.getElementById('writesWindow').textContent = '(last ' + writes.windowDays + ' days)';
  document.getElementById('writesHint').textContent =
    'Data points written/day (one per event) vs. the ' + fmtNum(writes.freeDailyLimit || 0) +
    '/day free-plan cap. Requests are batched (up to 25 events each), so this line — the write count — is the upper bound on both caps. Always counts every channel, including debug: all writes bill the same.';
  renderLineChart(document.getElementById('writesTrend'), writes.trend, 'writes', '#fbbf24', writes.freeDailyLimit || 0);

  document.getElementById('funnelHint').textContent = 'Distinct users at each step ' + win;
  renderFunnels(document.getElementById('funnels'), usersByEvent);
  renderOnboardingFunnel(document.getElementById('funnels'), data.paramEvents);

  document.getElementById('compareHint').textContent =
    'Adding content: total events ' + win + '. Player navigation: throttled to one event per user per day, so these are user-days, not taps.';
  renderCompare(document.getElementById('compare'), countsByEvent);

  document.getElementById('breakdownHint').textContent = 'Consolidated events broken out by their parameters ' + win;
  document.getElementById('playbackStartWindow').textContent = win;
  renderPie(document.getElementById('playbackStartPie'), aggregateParam(data.paramEvents || [], 'Player.Start', 'source'));

  renderBreakdowns(document.getElementById('breakdowns'), data.paramEvents);

  const searchUsage = data.searchUsage || {};
  document.getElementById('searchWindow').textContent = '(last ' + searchUsage.windowDays + ' days)';
  document.getElementById('searchHint').textContent =
    'Distinct people per day who searched in the app, turned on YouTube mode, or did anything in a YouTube page (Search tab or browser sheet). ' +
    'Per version: share of active users on that version who did it at least once. Hidden YouTube buttons: see Settings adoption and Search.HideYoutubeButton.';
  renderSearchUsage(document.getElementById('searchTrend'), document.getElementById('searchBreakdowns'), searchUsage);

  document.getElementById('generationWindow').textContent = win;
  renderGenerationResults(document.getElementById('generation'), data.paramEvents);

  const settingsBase = 'Based on ' + data.settings.sampleSize + ' users active in the last ' +
    data.settings.windowDays + ' days. Users who never touched a setting are counted on its default.';
  renderSettingsGrid(document.getElementById('settingsGrid'), document.getElementById('settingsToggle'), data.settings);
  renderValueSettings(
    document.getElementById('settingValues'),
    document.getElementById('settingValuesToggle'),
    data.settings.values || {}
  );

  const settingsTrendBase = 'Each point is the users who sent a settings snapshot in that ' + data.settings.trendPeriodDays +
    '-day period, over the last ' + data.settings.trendWindowDays + ' days; users who never touched a setting count on its default, ' +
    'as above. The latest period is still filling in.' + truncatedNote(data.settings.trendTruncated);
  const settingsHint = document.getElementById('settingsHint');
  setupViewSwitch('settings', document.getElementById('settingsSwitch'), [
    { id: 'now', label: 'Now', elements: [document.getElementById('settingsNow')], onShow: function () { settingsHint.textContent = settingsBase; } },
    { id: 'trend', label: 'Over time', elements: [document.getElementById('settingsTrendView')], renderOnce: function () {
      renderSettingsTrendGrid(document.getElementById('settingsTrendGrid'), document.getElementById('settingsTrendToggle'), data.settings);
    }, onShow: function () {
      settingsHint.textContent = 'Share with each setting on. Sorted by how much that share moved. ' + settingsTrendBase;
    } },
  ]);
  const settingValuesHint = document.getElementById('settingValuesHint');
  setupViewSwitch('settingValues', document.getElementById('settingValuesSwitch'), [
    { id: 'now', label: 'Now', elements: [document.getElementById('settingValuesNow')], onShow: function () { settingValuesHint.textContent = settingsBase; } },
    { id: 'trend', label: 'Over time', elements: [document.getElementById('settingValuesTrendView')], renderOnce: function () {
      renderValueSettingsTrend(document.getElementById('settingValuesTrend'), document.getElementById('settingValuesTrendToggle'), data.settings);
    }, onShow: function () {
      settingValuesHint.textContent = 'Share of users on each value. ' + settingsTrendBase;
    } },
  ]);

  document.getElementById('queueHint').textContent =
    'Based on ' + data.queueInbox.queue.sampleSize + ' users active in the last ' + data.queueInbox.windowDays + ' days';
  renderBucketBars(document.getElementById('queueBars'), data.queueInbox.queue.buckets);

  document.getElementById('inboxHint').textContent =
    'Based on ' + data.queueInbox.inbox.sampleSize + ' users active in the last ' + data.queueInbox.windowDays + ' days';
  renderBucketBars(document.getElementById('inboxBars'), data.queueInbox.inbox.buckets);

  document.getElementById('subsHint').textContent =
    'Based on ' + data.subscriptions.sampleSize + ' users active in the last ' + data.subscriptions.windowDays + ' days';
  renderBucketBars(document.getElementById('subsBars'), data.subscriptions.buckets);

  document.getElementById('podcastSubsHint').textContent =
    'Based on ' + (data.subscriptions.podcastSampleSize ?? 0) + ' users reporting a podcast count in the last ' +
    data.subscriptions.windowDays + ' days';
  renderBucketBars(document.getElementById('podcastSubsBars'), data.subscriptions.podcastBuckets || {});

  renderSubscriptionSettings(document.getElementById('subSettingsBars'),
    document.getElementById('subSettingsHint'), data.subscriptions.settings, data.subscriptions.windowDays);

  const qi = data.queueInbox, subs = data.subscriptions;
  const libraryTrendHint = document.getElementById('libraryTrendHint');
  libraryTrendHint.textContent = 'Share of reporting users in each size range per period, over the last ' + qi.trendWindowDays + ' days. ' +
    'Queue and inbox report weekly, so each point is one ' + qi.trendPeriodDays + '-day period; subscriptions report fortnightly (' +
    subs.trendPeriodDays + '-day periods). The latest point is still filling in. ' +
    'Someone whose size changed range within a period counts once in each range.' + truncatedNote(subs.trendTruncated);
  setupViewSwitch('library', document.getElementById('librarySwitch'), [
    { id: 'now', label: 'Now', elements: [document.getElementById('libraryNow')] },
    { id: 'trend', label: 'Over time', elements: [document.getElementById('libraryTrend'), libraryTrendHint], renderOnce: function () {
      renderBucketTrend(document.getElementById('queueTrend'), 'Queue size', qi.queueTrend, Object.keys(qi.queue.buckets));
      renderBucketTrend(document.getElementById('inboxTrend'), 'Inbox size', qi.inboxTrend, Object.keys(qi.inbox.buckets));
      renderBucketTrend(document.getElementById('subsTrend'), 'Subscription count', subs.trend, Object.keys(subs.buckets));
      renderBucketTrend(document.getElementById('podcastSubsTrend'), 'Podcast subscriptions', subs.podcastTrend, Object.keys(subs.podcastBuckets || subs.buckets));
    } },
  ]);

  document.getElementById('errorWindow').textContent = '(last ' + data.errors.windowDays + ' days)';
  renderErrors(document.getElementById('errorTrend'), document.getElementById('errors'), data.errors);

  renderRecent(data.recent);
  finishLoading();
}).catch(err => {
  document.getElementById('error').textContent = err;
  finishLoading();
});
