const YOUTUBE_VIDEO = /^https?:\/\/(?:[\w-]+\.)?(?:youtube\.com\/(?:watch\?(?:[^#]*&)?v=|shorts\/|live\/)|youtu\.be\/)([\w-]{11})/;
const APPLE_EPISODE = /^https:\/\/podcasts\.apple\.com\/(?:([a-z]{2})\/)?podcast\/(?:[^/]+\/)?id(\d+)\?i=(\d+)/;

export function sharedItem(url) {
  const [first, ...rest] = url.pathname.split("/").filter(Boolean);
  const params = url.searchParams;
  if (first === "v" && rest.length === 1) {
    return youtube(rest[0], params.get("t"), `unwatched://open${url.search ? `${url.search}&` : "?"}v=${rest[0]}`);
  }
  if (first === "p" && rest.length === 2) {
    const shared = podcast(rest[0], rest[1], params.get("c"));
    const start = params.get("t");
    if (!shared || !start || !/^\d+$/.test(start)) return shared;
    return { ...shared, inApp: `${shared.inApp}&t=${start}` };
  }
  if (!["open", "play", "queue", "inbox"].includes(first)) {
    return null;
  }
  const inApp = `unwatched://${first}${url.search}`;
  const link = params.get("url");
  if (link) {
    const apple = link.match(APPLE_EPISODE);
    if (apple) return { ...podcast(apple[2], apple[3], apple[1]), inApp };
    const video = link.match(YOUTUBE_VIDEO);
    if (video) return { ...youtube(video[1], new URL(link).searchParams.get("t")?.replace(/s$/, "") ?? null, inApp), target: link };
    return /^https?:\/\//.test(link) ? { kind: "link", target: link, inApp } : null;
  }
  const v = params.get("v");
  return v ? youtube(v, params.get("t"), inApp) : null;
}

function youtube(id, start, inApp) {
  if (!/^[\w-]{11}$/.test(id)) return null;
  const seconds = start && /^\d+$/.test(start) ? start : null;
  const target = `https://www.youtube.com/watch?v=${id}${seconds ? `&t=${seconds}s` : ""}`;
  const embed = `https://www.youtube-nocookie.com/embed/${id}${seconds ? `?start=${seconds}` : ""}`;
  return { kind: "youtube", id, target, embed, inApp: inApp ?? `unwatched://open?url=${encodeURIComponent(target)}` };
}

function podcast(showId, episodeId, country) {
  if (!/^\d+$/.test(showId) || !/^\d+$/.test(episodeId)) return null;
  const store = country && /^[a-z]{2}$/i.test(country) ? country.toLowerCase() : null;
  const target = `https://podcasts.apple.com/${store ? `${store}/` : ""}podcast/id${showId}?i=${episodeId}`;
  return { kind: "podcast", showId, episodeId, store, target, inApp: `unwatched://open?url=${encodeURIComponent(target)}` };
}
