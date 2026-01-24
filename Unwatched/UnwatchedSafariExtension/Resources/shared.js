// shared.js

function isYouTubeVideoUrl(url) {
  try {
    const urlObj = new URL(url);
    const hostname = urlObj.hostname;
    const pathname = urlObj.pathname;

    // Check for various YouTube video URL patterns
    if (hostname.includes("youtube.com")) {
      // Standard watch page: /watch?v=...
      if (pathname === "/watch" && urlObj.searchParams.has("v")) {
        return true;
      }
      // Shorts: /shorts/VIDEO_ID
      if (pathname.startsWith("/shorts/")) {
        return true;
      }
      // Live videos: /live/VIDEO_ID
      if (pathname.startsWith("/live/")) {
        return true;
      }
    }

    // Short URLs: youtu.be/VIDEO_ID
    if (hostname === "youtu.be" && pathname.length > 1) {
      return true;
    }

    return false;
  } catch (e) {
    return false;
  }
}

function getUnwatchedDeepLink(url) {
  return (
    "unwatched://play?url=" +
    encodeURIComponent(url) +
    "&source=safari_extension"
  );
}
