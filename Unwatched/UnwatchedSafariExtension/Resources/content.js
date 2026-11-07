const APP_LINK = "https://u.octabits.net/play";
const isMac = navigator.maxTouchPoints === 0;

function isPlainClick(event) {
  return event.button === 0 && !event.metaKey && !event.ctrlKey && !event.shiftKey && !event.altKey;
}

function handleClick(event) {
  const anchor = event.target.closest?.("a[href]");
  if (!(anchor instanceof HTMLAnchorElement) || !isPlainClick(event)) return;
  const isRewritten = anchor.href.startsWith(APP_LINK);
  if (!isRewritten && !isYouTubeVideoUrl(anchor.href)) return;

  event.stopImmediatePropagation();
  if (isMac) {
    event.preventDefault();
    window.location.href = getUnwatchedPlayLink("unwatched://play", anchor.href);
    return;
  }
  // Universal links only open the app from a real link tap.
  anchor.removeAttribute("target");
  if (!isRewritten) anchor.href = getUnwatchedPlayLink(APP_LINK, anchor.href);
}

document.addEventListener("click", handleClick, true);
