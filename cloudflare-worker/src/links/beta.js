import { escapeHtml } from "../reports/format.js";

// While BETA_JOIN_URL is empty, /beta collects addresses instead of redirecting, so the
// new TestFlight can invite everyone at once (ASC → TestFlight → Testers → Import CSV).
const MAX_EMAIL_LENGTH = 254;
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const SIGNUP_TTL_SECONDS = 365 * 24 * 60 * 60;
const SIGNUP_PREFIX = "beta:";

export async function handleBeta(request, env) {
  if (env.BETA_JOIN_URL) {
    return Response.redirect(env.BETA_JOIN_URL, 302);
  }
  if (request.method === "GET" || request.method === "HEAD") {
    return betaPage();
  }
  if (request.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const clientIp = request.headers.get("CF-Connecting-IP") ?? "unknown";
  const { success } = await env.BETA_LIMITER.limit({ key: clientIp });
  if (!success) {
    return betaPage("error", "Too many attempts — please try again in a minute.", 429);
  }

  let form;
  try {
    form = await request.formData();
  } catch {
    return betaPage("error", "Something went wrong — please try again.", 400);
  }
  // hidden from people, filled in by form-spamming bots
  if (String(form.get("website") ?? "")) {
    return betaPage("done");
  }
  const email = String(form.get("email") ?? "").trim().toLowerCase();
  if (email.length > MAX_EMAIL_LENGTH || !EMAIL_PATTERN.test(email)) {
    return betaPage("error", "That doesn't look like an email address.", 400);
  }

  // keyed by address, so signing up twice doesn't create a second row
  const key = `${SIGNUP_PREFIX}${email}`;
  if (!(await env.REPORTS.get(key))) {
    await env.REPORTS.put(key, JSON.stringify({ email, createdAt: new Date().toISOString() }), {
      expirationTtl: SIGNUP_TTL_SECONDS,
    });
  }
  return betaPage("done");
}

export async function listBetaSignups(env) {
  const signups = [];
  let cursor;
  do {
    const listed = await env.REPORTS.list({ prefix: SIGNUP_PREFIX, cursor });
    const values = await Promise.all(listed.keys.map((key) => env.REPORTS.get(key.name, { type: "json" })));
    signups.push(...values.filter(Boolean));
    cursor = listed.list_complete ? undefined : listed.cursor;
  } while (cursor);
  return signups.sort((a, b) => (a.createdAt < b.createdAt ? 1 : -1));
}

export async function handleBetaDashboard(url, env) {
  const signups = await listBetaSignups(env);
  if (url.pathname === "/dashboard/beta.csv") {
    // App Store Connect's tester import: first name, last name, email — no header row
    const csv = signups.map(({ email }) => `,,${email}`).join("\n");
    return new Response(`${csv}\n`, {
      headers: {
        "Content-Type": "text/csv; charset=utf-8",
        "Content-Disposition": 'attachment; filename="unwatched-beta-testers.csv"',
      },
    });
  }
  const rows = signups
    .map(({ email, createdAt }) => `<tr><td>${escapeHtml(email)}</td><td>${escapeHtml(createdAt.slice(0, 10))}</td></tr>`)
    .join("");
  const html = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Beta Waitlist</title>
<style>
  :root { --bg: #f6f6f7; --card: #fff; --text: #1c1c1e; --muted: #6e6e73; --border: #e3e3e6; --accent: #d93a2b; }
  @media (prefers-color-scheme: dark) {
    :root { --bg: #111113; --card: #1c1c1f; --text: #f2f2f4; --muted: #9a9aa0; --border: #2c2c30; --accent: #ff6b5c; }
  }
  body { margin: 0; padding: 24px 16px; background: var(--bg); color: var(--text); font: 15px/1.5 -apple-system, system-ui, sans-serif; }
  main { max-width: 760px; margin: 0 auto; display: grid; gap: 16px; }
  h1 { font-size: 22px; margin: 0; }
  nav { display: flex; justify-content: space-between; }
  a { color: var(--accent); }
  table { width: 100%; border-collapse: collapse; background: var(--card); border: 1px solid var(--border); border-radius: 12px; overflow: hidden; }
  td { padding: 8px 12px; border-top: 1px solid var(--border); overflow-wrap: anywhere; }
  tr:first-child td { border-top: none; }
  td:last-child { color: var(--muted); white-space: nowrap; width: 1%; }
  .empty { color: var(--muted); }
</style>
</head>
<body>
<main>
  <nav><a href="/dashboard">← Analytics</a><a href="/dashboard/beta.csv">Download CSV for App Store Connect</a></nav>
  <h1>Beta Waitlist · ${signups.length}</h1>
  ${signups.length ? `<table>${rows}</table>` : '<p class="empty">No signups yet.</p>'}
</main>
</body>
</html>`;
  return new Response(html, { headers: { "Content-Type": "text/html; charset=utf-8" } });
}

function betaPage(state, message = "", status = 200) {
  const content = state === "done"
    ? `<h1>You're on the list</h1>
  <p>We'll send you a TestFlight invite as soon as the new beta is up.</p>`
    : `<h1>The beta will be back shortly</h1>
  <p>Unwatched's TestFlight is moving to a new developer account. Leave your email and you'll get an invite as soon as it's open again.</p>
  <form method="post" action="/beta">
    <input type="email" name="email" required autocomplete="email" placeholder="you@example.com" aria-label="Email" maxlength="${MAX_EMAIL_LENGTH}">
    <input type="text" name="website" class="trap" tabindex="-1" autocomplete="off" aria-hidden="true">
    <button type="submit">Notify me</button>
  </form>
  ${message ? `<p class="error">${escapeHtml(message)}</p>` : ""}
  <p class="fine">Your address is only used to send the TestFlight invite.</p>`;
  const html = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Unwatched Beta</title>
<style>
  :root { color-scheme: dark; --card: #1c1c1e; --text: #f2f2f7; --muted: #98989d; --accent: #0aa; --field: #2c2c2e; }
  * { box-sizing: border-box; }
  body { margin: 0; min-height: 100vh; background: #000; color: var(--text);
         font: 17px/1.35 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
         display: flex; align-items: center; justify-content: center; padding: 16px; }
  main { width: 100%; max-width: 440px; background: var(--card); border-radius: 28px; padding: 24px; display: grid; gap: 14px; }
  h1 { font-size: 22px; line-height: 1.25; margin: 0; }
  p { margin: 0; color: var(--muted); font-size: 15px; }
  form { display: grid; gap: 10px; margin-top: 6px; }
  input { font: inherit; color: var(--text); background: var(--field); border: none; border-radius: 14px; padding: 14px 16px; width: 100%; }
  input:focus { outline: 2px solid var(--accent); }
  button { font: inherit; font-weight: 600; color: #fff; background: var(--accent); border: none; border-radius: 999px; padding: 14px 10px; cursor: pointer; }
  .trap { position: absolute; left: -9999px; }
  .error { color: #ff6b5c; }
  .fine { font-size: 13px; }
</style>
</head>
<body>
<main>
  ${content}
</main>
</body>
</html>`;
  return new Response(html, {
    status,
    headers: { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "no-store" },
  });
}
