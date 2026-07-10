import { isDashboardAuthorized, dashboardCookieHeader, handleDashboardData, handleRecentData, DASHBOARD_HTML } from "./dashboard.js";

const MAX_EVENTS_PER_REQUEST = 25;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.pathname === "/dashboard" || url.pathname === "/dashboard/data" || url.pathname === "/dashboard/recent") {
      if (!(await isDashboardAuthorized(request, env))) {
        return new Response("Unauthorized", {
          status: 401,
          headers: { "WWW-Authenticate": 'Basic realm="dashboard"' },
        });
      }
      // Refresh the long-lived login cookie on every authorized request so an
      // active user keeps a rolling 30-day window instead of being logged out.
      const setCookie = await dashboardCookieHeader(env);
      if (url.pathname === "/dashboard/data" || url.pathname === "/dashboard/recent") {
        const res = url.pathname === "/dashboard/recent"
          ? await handleRecentData(env)
          : await handleDashboardData(env);
        res.headers.append("Set-Cookie", setCookie);
        return res;
      }
      return new Response(DASHBOARD_HTML, {
        headers: { "Content-Type": "text/html; charset=utf-8", "Set-Cookie": setCookie },
      });
    }

    if (request.method !== "POST") {
      return new Response("Method not allowed", { status: 405 });
    }

    // Per-IP rate limit. The ingest bearer token ships in the app and is extractable, so
    // this caps how much any single source can write regardless of the token. Checked
    // before auth so an unauthenticated flood is throttled too. Dashboard reads are handled
    // above and never reach here.
    const clientIp = request.headers.get("CF-Connecting-IP") ?? "unknown";
    const { success } = await env.INGEST_LIMITER.limit({ key: clientIp });
    if (!success) {
      return new Response("Rate limit exceeded", { status: 429 });
    }

    if (request.headers.get("Authorization") !== `Bearer ${env.API_SECRET}`) {
      return new Response("Unauthorized", { status: 401 });
    }

    let body;
    try {
      body = await request.json();
    } catch {
      return new Response("Invalid JSON", { status: 400 });
    }

    const events = body.events;
    if (!Array.isArray(events) || events.length === 0) {
      return new Response("Expected non-empty 'events' array", { status: 400 });
    }
    if (events.length > MAX_EVENTS_PER_REQUEST) {
      return new Response(`Max ${MAX_EVENTS_PER_REQUEST} events per request`, { status: 400 });
    }

    for (const event of events) {
      env.ANALYTICS.writeDataPoint({
        // blobs: string fields, up to 20. params is an arbitrary string dict,
        // stored as JSON since Signal.log() call sites pass varying keys.
        // userId is a random, non-identifying per-install id (see AnalyticsEvent.swift)
        // used to count unique/active users and dedupe per-user settings snapshots.
        blobs: [
          event.name ?? "unknown",
          JSON.stringify(event.params ?? {}),
          event.userId ?? "unknown",
        ],
        // doubles: numeric fields, up to 20. clientTimestamp preserves when the
        // event actually happened, since ingestion time reflects when it was sent.
        doubles: [event.clientTimestamp ?? Date.now()],
        // indexes: used for filtering/grouping in queries, first value only
        indexes: [event.name ?? "unknown"],
      });
    }

    return new Response(null, { status: 204 });
  },
};
