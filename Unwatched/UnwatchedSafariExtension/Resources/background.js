// background.js

browser.webNavigation.onBeforeNavigate.addListener(
  (details) => {
    if (details.frameId !== 0) return; // Only handle main frame

    if (isYouTubeVideoUrl(details.url)) {
      console.log("Intercepted YouTube URL navigation:", details.url);
      const deepLink = getUnwatchedDeepLink(details.url);

      browser.tabs.update(details.tabId, { url: deepLink });
    }
  },
  {
    url: [{ hostSuffix: "youtube.com" }, { hostSuffix: "youtu.be" }],
  },
);
