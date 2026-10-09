// Public links the app ships with, served on unwatched.octabits.net. The app points at
// these instead of the destination so a target can change (e.g. the TestFlight join link
// after moving the app to another App Store account) without an app update.
export const LINKS_HOST = "unwatched.octabits.net";

// 302, not 301: browsers cache a 301 indefinitely, which would pin people to an old target.
const LINKS = {
  "/beta": "https://testflight.apple.com/join/9RP0WzCR",
};

export function handleLink(url) {
  const target = LINKS[url.pathname.replace(/\/+$/, "")];
  if (!target) {
    return new Response("Not found", { status: 404 });
  }
  return Response.redirect(target, 302);
}
