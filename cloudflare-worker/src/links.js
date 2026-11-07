import { sharedItem, preview } from "./links/shared.js";
import { fallbackPage } from "./links/page.js";

export const LINKS_HOSTS = new Set(["unwatched.octabits.net", "u.octabits.net"]);

const APP_ID = "HU6B6E9383.com.pentlandFirth.Unwatched";
const APP_PATHS = ["/v/*", "/p/*", "/open*", "/play*", "/queue*", "/inbox*"];

// 302, not 301: browsers cache a 301 indefinitely, which would pin people to an old target.
const LINKS = {
  "/beta": "https://testflight.apple.com/join/9RP0WzCR",
};

export async function handleLink(url) {
  const path = url.pathname.replace(/\/+$/, "");
  if (path === "/.well-known/apple-app-site-association") {
    return Response.json({
      applinks: { details: [{ appIDs: [APP_ID], components: APP_PATHS.map((p) => ({ "/": p })) }] },
    });
  }
  const target = LINKS[path];
  if (target) {
    return Response.redirect(target, 302);
  }
  const shared = sharedItem(url);
  if (!shared) {
    return new Response("Not found", { status: 404 });
  }
  return fallbackPage(url, shared, await preview(shared));
}
