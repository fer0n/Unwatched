const APP_STORE_URL = "https://apps.apple.com/app/id6477287463";
const EXTERNAL_LABELS = { podcast: "Listen in Apple Podcasts", youtube: "Watch on YouTube" };

const escapeHtml = (s) => String(s ?? "").replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);

const media = (shared) =>
  shared.embed
    ? `<iframe class="video" src="${escapeHtml(shared.embed)}" title="YouTube video player" allow="encrypted-media; picture-in-picture; fullscreen" allowfullscreen></iframe>`
    : "";

export function fallbackPage(url, shared, { title, subtitle, image, imageWidth, imageHeight }) {
  const pageTitle = title ?? "Shared with Unwatched";
  const externalLabel = EXTERNAL_LABELS[shared.kind] ?? "Open link";
  const artwork = shared.kind === "podcast" && image ? `<img class="artwork" src="${escapeHtml(image)}" alt="">` : "";
  const html = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${escapeHtml(pageTitle)}</title>
<meta property="og:title" content="${escapeHtml(pageTitle)}">
${subtitle ? `<meta property="og:description" content="${escapeHtml(subtitle)}">` : ""}
${image ? `<meta property="og:image" content="${escapeHtml(image)}">` : ""}
${imageWidth ? `<meta property="og:image:width" content="${imageWidth}">` : ""}
${imageHeight ? `<meta property="og:image:height" content="${imageHeight}">` : ""}
<meta property="og:url" content="${escapeHtml(url.href)}">
<meta name="apple-itunes-app" content="app-id=6477287463, app-argument=${escapeHtml(url.href)}">
<style>
  :root { color-scheme: dark; --card: #1c1c1e; --text: #f2f2f7; --muted: #98989d; --accent: #0aa; }
  * { box-sizing: border-box; }
  body { margin: 0; min-height: 100vh; background: #000; color: var(--text);
         font: 17px/1.35 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
         display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 32px; padding: 16px 0; }
  .video { width: 100%; max-width: 720px; aspect-ratio: 16 / 9; object-fit: cover; display: block; border: 0;
           background: #000; }
  .card { width: calc(100% - 32px); max-width: 480px; background: var(--card); border-radius: 28px; padding: 20px;
          display: grid; gap: 16px; }
  .info { display: flex; gap: 14px; align-items: center; }
  .artwork { width: 64px; height: 64px; border-radius: 12px; object-fit: cover; flex: none; }
  h1 { font-size: 20px; line-height: 1.25; margin: 0; }
  p { margin: 2px 0 0; color: var(--muted); font-size: 15px; }
  a { display: block; text-align: center; text-decoration: none; font-weight: 600; border-radius: 999px; }
  .actions { display: grid; gap: 10px; }
  .primary { background: var(--accent); color: #fff; padding: 14px 10px; }
  .tinted { background: color-mix(in srgb, var(--accent) 15%, transparent); color: var(--accent); padding: 14px 10px; }
  .secondary { color: var(--accent); padding: 4px; font-size: 15px; }
</style>
</head>
<body>
${media(shared)}
<main class="card">
  <div class="info">
    ${artwork}
    <div>
      <h1>${escapeHtml(pageTitle)}</h1>
      ${subtitle ? `<p>${escapeHtml(subtitle)}</p>` : ""}
    </div>
  </div>
  <div class="actions">
    <a class="primary" href="${escapeHtml(shared.inApp)}">Open in Unwatched</a>
    <a class="tinted" href="${APP_STORE_URL}">Get Unwatched</a>
  </div>
  <a class="secondary" href="${escapeHtml(shared.target)}">${externalLabel}</a>
</main>
</body>
</html>`;
  return new Response(html, {
    headers: { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "public, max-age=3600" },
  });
}
