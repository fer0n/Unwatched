import { escapeHtml, formatBytes } from "./format.js";
import { reportAttachments } from "./report.js";

export function reportsPage(reports, archived) {
  const items = reports.map((report) => reportItem(report, archived)).join("");
  const empty = archived ? "No archived reports." : "No reports in the last 180 days.";
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Unwatched Reports</title>
<style>
  :root { --bg: #f6f6f7; --card: #fff; --text: #1c1c1e; --muted: #6e6e73; --border: #e3e3e6; --accent: #d93a2b; }
  @media (prefers-color-scheme: dark) {
    :root { --bg: #111113; --card: #1c1c1f; --text: #f2f2f4; --muted: #9a9aa0; --border: #2c2c30; --accent: #ff6b5c; }
  }
  body { margin: 0; padding: 24px 16px; background: var(--bg); color: var(--text); font: 15px/1.5 -apple-system, system-ui, sans-serif; }
  main { max-width: 760px; margin: 0 auto; display: grid; gap: 16px; }
  h1 { font-size: 22px; margin: 0; }
  nav { display: flex; justify-content: space-between; }
  nav a, footer a { color: var(--accent); }
  form { display: inline; }
  button { font: inherit; color: var(--accent); background: none; border: none; padding: 0; cursor: pointer; }
  article { background: var(--card); border: 1px solid var(--border); border-radius: 12px; padding: 16px; }
  article:target { outline: 2px solid var(--accent); }
  article header { display: flex; flex-wrap: wrap; gap: 4px 16px; color: var(--muted); font-size: 13px; }
  .message { white-space: pre-wrap; overflow-wrap: anywhere; margin: 12px 0; }
  article footer { color: var(--muted); font-size: 13px; }
  img, video { display: block; max-width: 100%; max-height: 480px; margin-top: 12px; border-radius: 8px; }
  .empty { color: var(--muted); }
</style>
</head>
<body>
<main>
  <nav>
    <a href="/dashboard">← Analytics</a>
    ${archived ? '<a href="/dashboard/reports">Reports</a>' : '<a href="/dashboard/reports/archived">Archived</a>'}
  </nav>
  <h1>${archived ? "Archived Reports" : "Reports"}</h1>
  ${items || `<p class="empty">${empty}</p>`}
</main>
</body>
</html>`;
}

function reportItem(report, archived) {
  const base = `/dashboard/reports/${encodeURIComponent(report.id)}`;
  const createdAt = new Date(report.createdAt).toLocaleString("en-GB", { timeZone: "Europe/Berlin" });
  const contact = report.contact
    ? `<a href="mailto:${encodeURIComponent(report.contact)}">${escapeHtml(report.contact)}</a>`
    : "no reply address";
  const log = report.log
    ? `<a href="${base}/log" target="_blank">Log (${formatBytes(report.log.size)})</a>`
    : "no log";
  return `
    <article id="${escapeHtml(report.id)}">
      <header>
        <time datetime="${escapeHtml(report.createdAt)}">${escapeHtml(createdAt)}</time>
        <span>${escapeHtml(report.appVersion)} (${escapeHtml(report.build)}) · ${escapeHtml(report.channel)}</span>
        <span>${escapeHtml(report.device)} · ${escapeHtml(report.os)}</span>
      </header>
      <p class="message">${escapeHtml(report.message)}</p>
      <footer>${contact} · ${log} · ${archiveButton(report, base, archived)}</footer>
      ${attachmentPreviews(report, base)}
    </article>`;
}

function archiveButton(report, base, archived) {
  if (!archived) {
    return `<form method="post" action="${base}/archive"><button>Archive</button></form>`;
  }
  const deletedOn = new Date(report.expiration * 1000).toLocaleDateString("en-GB", { timeZone: "Europe/Berlin" });
  return `deleted on ${escapeHtml(deletedOn)} · <form method="post" action="${base}/restore"><button>Restore</button></form>`;
}

function attachmentPreviews(report, base) {
  return reportAttachments(report)
    .map(({ type, index }) => attachmentPreview({ type, src: `${base}/attachment${index === undefined ? "" : `/${index}`}` }))
    .join("");
}

function attachmentPreview({ type, src }) {
  if (type.startsWith("video/")) {
    return `<video controls preload="metadata" src="${src}"></video>`;
  }
  return `<a href="${src}" target="_blank"><img src="${src}" alt="Attachment"></a>`;
}
