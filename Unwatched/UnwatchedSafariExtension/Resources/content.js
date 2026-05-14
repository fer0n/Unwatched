// content.js

function openInUnwatched(url) {
  console.log("Opening in Unwatched: " + url);
  window.location.href = getUnwatchedDeepLink(url);
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

document.addEventListener("click", handleClick, true);
