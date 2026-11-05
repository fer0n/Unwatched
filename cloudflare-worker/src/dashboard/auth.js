const AUTH_COOKIE = "dashboard_auth";
// How long a successful login stays valid without re-entering the password.
const AUTH_COOKIE_MAX_AGE = 60 * 60 * 24 * 30; // 30 days

// Non-reversible token derived from the password, safe to store in a cookie.
async function authToken(env) {
  const data = new TextEncoder().encode(`${env.DASHBOARD_PASSWORD}:unwatched-dashboard`);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

// Set-Cookie value that keeps the login alive across browser sessions.
export async function dashboardCookieHeader(env) {
  const token = await authToken(env);
  return `${AUTH_COOKIE}=${token}; Max-Age=${AUTH_COOKIE_MAX_AGE}; Path=/dashboard; HttpOnly; Secure; SameSite=Lax`;
}

export async function isDashboardAuthorized(request, env) {
  const expected = await authToken(env);
  const cookie = request.headers.get("Cookie") || "";
  if (cookie.split(/;\s*/).includes(`${AUTH_COOKIE}=${expected}`)) return true;

  const auth = request.headers.get("Authorization") || "";
  if (!auth.startsWith("Basic ")) return false;
  const decoded = atob(auth.slice(6));
  const password = decoded.split(":")[1] ?? "";
  return password === env.DASHBOARD_PASSWORD;
}
