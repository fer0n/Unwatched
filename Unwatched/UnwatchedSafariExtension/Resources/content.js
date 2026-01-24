// content.js

let lastUrl = location.href;
const openedUrls = new Set();

function openInUnwatched(url) {
  console.log("Opening in Unwatched: " + url);
  openedUrls.add(url);

  const deepLink = getUnwatchedDeepLink(url);
  window.location.href = deepLink;

  return true;
}

function checkAndOpen() {
  const url = window.location.href;

  if (isYouTubeVideoUrl(url)) {
    openInUnwatched(url);
  }
}

// Intercept clicks on links before navigation
function handleClick(event) {
  let target = event.target;

  // Walk up the DOM tree to find an anchor tag
  while (target && target.tagName !== "A") {
    target = target.parentElement;
    if (!target) return;
  }

  const href = target.href;
  if (href && isYouTubeVideoUrl(href)) {
    console.log("Intercepted click on YouTube video link:", href);
    event.preventDefault();
    event.stopPropagation();
    openInUnwatched(href);
  }
}

// Add click listener to intercept video link clicks
document.addEventListener("click", handleClick, true);

// Initial check when page loads
checkAndOpen();
