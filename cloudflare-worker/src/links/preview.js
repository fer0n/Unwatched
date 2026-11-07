const DAY = 86400;
const HOUR = 3600;
const CACHED = { cf: { cacheTtl: DAY, cacheEverything: true } };

export async function preview(shared) {
  try {
    if (shared.kind === "youtube") {
      const [res, image] = await Promise.all([
        fetch(`https://www.youtube.com/oembed?format=json&url=${encodeURIComponent(shared.target)}`, CACHED),
        youtubeThumbnail(shared.id),
      ]);
      if (!res.ok) return image;
      const data = await res.json();
      return { title: data.title, subtitle: data.author_name, ...image };
    }
    if (shared.kind === "podcast") {
      const params = new URLSearchParams({ id: shared.showId, entity: "podcastEpisode", limit: "200" });
      if (shared.store) params.set("country", shared.store);
      const res = await fetch(`https://itunes.apple.com/lookup?${params}`, CACHED);
      if (!res.ok) return {};
      const { results = [] } = await res.json();
      const episode = results.find((r) => String(r.trackId) === shared.episodeId);
      const show = results.find((r) => r.wrapperType === "track");
      return {
        title: episode?.trackName,
        subtitle: show?.collectionName ?? episode?.collectionName,
        image: episode?.artworkUrl600 ?? show?.artworkUrl600,
      };
    }
  } catch {
    return {};
  }
  return {};
}

// oEmbed's hqdefault is letterboxed 4:3; maxres is 16:9 but can be missing, mqdefault always exists.
async function youtubeThumbnail(id) {
  const maxres = `https://i.ytimg.com/vi/${id}/maxresdefault.jpg`;
  try {
    const res = await fetch(maxres, { method: "HEAD", cf: { cacheTtlByStatus: { "200-299": DAY, "404": HOUR }, cacheEverything: true } });
    if (res.ok) return { image: maxres, imageWidth: 1280, imageHeight: 720 };
  } catch {}
  return { image: `https://i.ytimg.com/vi/${id}/mqdefault.jpg`, imageWidth: 320, imageHeight: 180 };
}
