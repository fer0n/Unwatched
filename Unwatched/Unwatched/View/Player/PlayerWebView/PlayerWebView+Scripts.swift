//
//  YouTubePlayerView.swift
//  Unwatched
//

import SwiftUI
import WebKit
import OSLog
import UnwatchedShared

extension PlayerWebView {

    @MainActor
    func loadPlayer(webView: WKWebView, startAt: Double, type: PlayerType) -> Bool {
        guard let youtubeId = player.video?.youtubeId else {
            Log.warning("loadPlayer: no youtubeId")
            return false
        }
        return PlayerWebView.loadPlayer(webView: webView, youtubeId: youtubeId, startAt: startAt, type: type)
    }

    /// Also used by `WebPlayerWarmup`, which loads the same page without a player to read from.
    @MainActor
    static func loadPlayer(webView: WKWebView, youtubeId: String, startAt: Double, type: PlayerType) -> Bool {
        let urlString = type == .youtube
            ? UrlService.getNonEmbeddedYoutubeUrl(youtubeId, startAt)
            : UrlService.getEmbeddedYoutubeUrl(youtubeId, startAt)

        guard let url = URL(string: urlString) else {
            Log.warning("loadPlayer: no url")
            return false
        }
        Log.info("loadPlayer: \(urlString)")

        var request = URLRequest(url: url)
        let referer = "https://app.local.com"
        request.setValue(referer, forHTTPHeaderField: "Referer")
        request.setValue("strict-origin-when-cross-origin", forHTTPHeaderField: "Referrer-Policy")
        webView.load(request)
        return true
    }

    /// Neutralizes the Page Visibility API (and related lifecycle signals) so YouTube's own
    /// player script can't tell the page is backgrounded and pause on its own.
    static func blockVisibilityChangeScript() -> String {
        """
        (function() {
            try {
                Object.defineProperty(document, 'hidden', { get: () => false, configurable: true });
                Object.defineProperty(document, 'visibilityState', { get: () => 'visible', configurable: true });
                document.hasFocus = () => true;

                const blockedTypes = ['visibilitychange', 'webkitvisibilitychange', 'pagehide', 'freeze'];
                const originalAddEventListener = EventTarget.prototype.addEventListener;
                EventTarget.prototype.addEventListener = function(type, listener, options) {
                    if (blockedTypes.includes(type)) {
                        return;
                    }
                    return originalAddEventListener.call(this, type, listener, options);
                };

                Object.defineProperty(document, 'onvisibilitychange', {
                    get: () => null, set: () => {}, configurable: true
                });
                Object.defineProperty(document, 'onwebkitvisibilitychange', {
                    get: () => null, set: () => {}, configurable: true
                });
            } catch (error) {
                // best-effort: if this throws, just leave visibility reporting untouched
            }
        })();
        """
    }

    static func playScript(unstarted: Bool) -> String {
        if unstarted {
            Log.info("PLAY: unstarted")
            return unstartedPlayScript
        }
        return "play();"
    }

    /// Starts a page that has never played. The click has to happen synchronously inside the
    /// `evaluateJavaScript` call: that is what carries the user gesture WebKit requires to start
    /// media, and going through YouTube's own player is what makes the video count as watched.
    static let unstartedPlayScript = """
                hideOverlay();
                function attemptClick() {
                    document.elementFromPoint(window.innerWidth / 2, window.innerHeight / 2)?.click();
                }
                attemptClick();
                setTimeout(() => checkResult(0), 50);
                function checkResult(retries) {
                    const retryClicks = window.location.href.includes('youtube-nocookie');
                    if (!video.paused) {
                        return;
                    }
                    if (isNaN(video?.duration)) {
                        const offlineElement = document.querySelector('.ytp-offline-slate-subtitle-text');
                        if (offlineElement) {
                            sendMessage("offline", offlineElement.innerText);
                        } else {
                            if (retryClicks) {
                                // Workaround: the click can happen before the nocookie player has
                                // finished loading; no other way of awaiting it worked.
                                const element = document.elementFromPoint(
                                    window.innerWidth / 2,
                                    window.innerHeight / 2
                                );
                                if (element.classList.contains('ytp-button') || retries > 0) {
                                    attemptClick();
                                }
                            }
                            if (retries < 4) {
                                setTimeout(() => checkResult(retries + 1), 50 * (retries + 1) * 2);
                            }
                        }
                    }
                }

                // Workaround: setTimeout for theater mode leads to auto play on macOS in some cases.
                if (!(video?.offsetWidth >= window.innerWidth * 0.98)) {
                    const theaterButton = document.querySelector(".ytp-size-button");
                    if (theaterButton) {
                        theaterButton.click();
                    }
                }
        """

    /// A repeat attempt at the play click, without the one-time setup `unstartedPlayScript` does around it.
    static func retryPlayScript(unstarted: Bool) -> String {
        guard unstarted else { return "play();" }
        return "document.elementFromPoint(window.innerWidth / 2, window.innerHeight / 2)?.click();"
    }

    /// The page's `video` global is null until the element has been found again after a rebuild.
    static func pauseScript() -> String {
        """
        (video ?? document.querySelector('video'))?.pause();
        """
    }

    /// `warmupMuted` is what makes it stick: `setupVideo()` runs again whenever the page rebuilds
    /// its media element and would otherwise unmute a page that is still warming up.
    static func muteScript(_ muted: Bool) -> String {
        """
        warmupMuted = \(muted);
        \(videoPropertyScript("muted", "\(muted)"))
        """
    }

    /// Assigns without going through the page's `video` global, which is null until the element
    /// has been found — the case the warmup runs into.
    static func videoPropertyScript(_ property: String, _ value: String) -> String {
        """
        if (document.querySelector('video')) {
            document.querySelector('video').\(property) = \(value);
        }
        """
    }

    static func seekToScript(_ seekTo: Double) -> String {
        """
        video.currentTime = \(seekTo);
        startAtTime = \(seekTo);
        """
    }

    static func setPlaybackRateScript(_ rate: Double) -> String {
        """
        playbackRate = \(rate);
        // defaultPlaybackRate is what the element resets to when YouTube reloads the media
        // (e.g. resuming from background); keep it in sync so the speed survives the reload.
        video.defaultPlaybackRate = \(rate);
        video.playbackRate = \(rate);
        """
    }

    static func enterPipScript() -> String {
        """
        if (document.pictureInPictureEnabled && !document.pictureInPictureElement) {
            video.requestPictureInPicture().catch(error => {
                sendMessage('pip', error);
            });
        } else {
            sendMessage('pip', "not even trying")
        }
        """
    }

    static func exitPipScript() -> String {
        "document.exitPictureInPicture();"
    }

    static func repairVideo(onRepair: @escaping () -> Void) {
        guard let webView = WebPlayerBackend.shared.webView else {
            Log.error("repairVideo: no webView")
            return
        }
        let script = PlayerWebView.videoRequiresReloadScript()
        webView.evaluateJavaScript(script) { result, _ in
            let requiresReload = result as? String == "true"
            Log.info("repairVideo: onRepair, requiresReload=\(requiresReload)")
            if requiresReload {
                onRepair()
            }
        }
    }

    // Workaround: on iOS 26 the player can go black and unresponsive; changing quality
    // fixes it. Should only trigger when the video element exists but isn't working.
    static func videoRequiresReloadScript() -> String {
        """
        function requiresReload() {
            const video = document.querySelector('video');
            let requiresReload = video && video?.readyState === 0;
            return requiresReload ? "true" : "false";
        }
        requiresReload();
        """
    }

    // swiftlint:disable function_body_length
    /// Override YouTube chapter indicators with custom chapters
    /// - Parameter playbackOrder: the chapters in the order they play, which is what seeking walks.
    static func setChapterMarkersScript(
        chapters: [SendableChapter],
        playbackOrder: [SendableChapter],
        videoDuration: Double,
        enableLogging: Bool) -> String {
        // Convert chapters to a JSON array of objects with startTime, endTime and isActive properties
        let chaptersData = chapters.compactMap { chapter in
            if chapter.startTime == 0 {
                return nil
            }
            return """
                {
                "startTime": \(chapter.startTime),
                "endTime": \(chapter.endTime ?? -1),
                "isActive": \(chapter.isActive)
                }
                """
        }.joined(separator: ", ")

        let seekChaptersData = playbackOrder.map { chapter in
            """
            {
            "startTime": \(chapter.startTime),
            "endTime": \(chapter.endTime ?? -1),
            "isActive": \(chapter.isActive)
            }
            """
        }.joined(separator: ", ")
        let isReordered = playbackOrder.map(\.startTime) != chapters.map(\.startTime)

        return """
        window.unwatchedChapters = [\(seekChaptersData)];
        window.hasInactiveChapters = window.unwatchedChapters.some(c => !c.isActive);
        window.hasReorderedChapters = \(isReordered);
        function findYouTubeProgressBar() {
          // Only accept the chaptered progress bar if it actually contains chapter elements
          let chapteredProgressBar = document.querySelector(
            ".ytChapteredProgressBarHost"
          );
          if (chapteredProgressBar) {
            const chapterElements = chapteredProgressBar.querySelectorAll(
              ".ytChapteredProgressBarChapteredPlayerBarChapter"
            );
            if (chapterElements && chapterElements.length > 0) {
              return {
                progressBar: chapteredProgressBar,
                isNewEmbedding: true,
                hasYoutubeChapters: true,
                chapterFormat: "new",
              };
            }
          }

          let oldChaptersContainer = document.querySelector(".ytp-chapters-container");
          if (oldChaptersContainer) {
            const chapterElements = oldChaptersContainer.querySelectorAll(
              ".ytp-chapter-hover-container"
            );
            if (chapterElements && chapterElements.length > 1) {
              return {
                progressBar: oldChaptersContainer,
                isNewEmbedding: false,
                hasYoutubeChapters: true,
                chapterFormat: "old",
              };
            }
          }

          let progressBar = document.querySelector(".ytProgressBarLineHost");
          let isNewEmbedding = true;
          if (!progressBar) {
            progressBar = document.querySelector(".ytp-progress-list");
            isNewEmbedding = false;
          }
          return {
            progressBar,
            isNewEmbedding,
            hasYoutubeChapters: false,
            chapterFormat: null,
          };
        }

        function removeCustomChapterAreas() {
          document
            .querySelectorAll(".custom-chapter-area")
            .forEach((area) => area.remove());
          document
            .querySelectorAll(".custom-chapter-overlay")
            .forEach((overlay) => overlay.remove());
        }

        function createChapterArea(
          chapter,
          videoDuration,
          isNewEmbedding,
          hasYoutubeChapters
        ) {
          const startPercent = (chapter.startTime / videoDuration) * 100;
          const endPercent = (chapter.endTime / videoDuration) * 100;
          const width = endPercent - startPercent;

          if (width < 0.1) return null;

          const area = document.createElement("div");
          area.className = "custom-chapter-area";
          area.style.position = "absolute";
          area.style.left = `${startPercent}%`;
          area.style.top = "0";
          area.style.bottom = "0";
          area.style.width = `${width}%`;
          area.style.pointerEvents = "none";

          if (!isNewEmbedding) {
            area.style.zIndex = "35";
          }

          if (hasYoutubeChapters) {
            area.style.borderLeft = "";
            area.style.backgroundColor = chapter.isActive
              ? "transparent"
              : "rgba(0, 0, 0, 0.5)";
            area.style.zIndex = "36";
          } else {
            area.style.borderLeft = "2px solid rgba(0, 0, 0, 0.7)";
            area.style.backgroundColor = chapter.isActive
              ? "transparent"
              : "rgba(0, 0, 0, 0.5)";
          }

          return area;
        }

        function extractYouTubeChapters(progressBar, videoDuration, chapterFormat) {
          let chapterElements;

          if (chapterFormat === "new") {
            chapterElements = progressBar.querySelectorAll(
              ".ytChapteredProgressBarChapteredPlayerBarChapter"
            );
          } else if (chapterFormat === "old") {
            chapterElements = progressBar.querySelectorAll(
              ".ytp-chapter-hover-container"
            );
          } else {
            return null;
          }

          if (!chapterElements || chapterElements.length === 0) {
            return null;
          }

          let hasValidChapters = false;

          if (chapterFormat === "old") {
            hasValidChapters = chapterElements.length > 1;

            let totalWidthCheck = 0;
            for (let i = 0; i < chapterElements.length; i++) {
              totalWidthCheck += parseFloat(chapterElements[i].style.width) || 0;
            }

            // Multiple chapters whose widths don't add up to anything significant means
            // something is wrong with the chapter data.
            if (hasValidChapters && totalWidthCheck < 10) {
              if (window.enableLogging) {
                sendMessage("setChapterMarker", "Chapter elements found but widths are too small");
              }
              hasValidChapters = false;
            }
          } else {
            for (let i = 0; i < chapterElements.length; i++) {
              if (parseFloat(chapterElements[i].style.width) > 0) {
                hasValidChapters = true;
                break;
              }
            }
          }

          if (!hasValidChapters) {
            return null;
          }

          let youtubeChapters = [];
          let currentTime = 0;
          let totalWidth = 0;

          if (chapterFormat === "old") {
            const progressBarWidth = progressBar.getBoundingClientRect().width;

            // In the old format, each chapter's width represents its proportion of the
            // total video. Try style.width first, and fall back to getBoundingClientRect
            // when the widths don't add up to anything meaningful.
            let sumWidth = 0;
            let useClientRect = false;

            chapterElements.forEach((chapter) => {
              const width = parseFloat(chapter.style.width) || 0;
              const marginRight = parseFloat(chapter.style.marginRight) || 0;
              sumWidth += width + marginRight;
            });

            if (sumWidth < 20) {
              sumWidth = 0;
              useClientRect = true;
              chapterElements.forEach((chapter) => {
                const rect = chapter.getBoundingClientRect();
                const width = rect.width;
                const style = window.getComputedStyle(chapter);
                const marginRight = parseFloat(style.marginRight) || 0;
                sumWidth += width + marginRight;
              });
            }

            let runningTime = 0;
            for (let i = 0; i < chapterElements.length; i++) {
              const chapter = chapterElements[i];
              let width, marginRight;

              if (useClientRect) {
                const rect = chapter.getBoundingClientRect();
                width = rect.width;
                const style = window.getComputedStyle(chapter);
                marginRight = parseFloat(style.marginRight) || 0;
              } else {
                width = parseFloat(chapter.style.width) || 0;
                marginRight = parseFloat(chapter.style.marginRight) || 0;
              }

              const totalWidth = width + marginRight;
              const chapterDuration = (totalWidth / sumWidth) * videoDuration;

              const startTime = runningTime;
              const isLastChapter = i === chapterElements.length - 1;
              // Make the last chapter end exactly at videoDuration to avoid gaps.
              const endTime = isLastChapter
                ? videoDuration
                : runningTime + chapterDuration;

              youtubeChapters.push({
                startTime,
                endTime,
                element: chapter,
              });

              runningTime = endTime;
            }

            if (window.enableLogging) {
              sendMessage(
                "setChapterMarker oldFormatChapters",
                JSON.stringify(
                  youtubeChapters.map((ch) => ({
                    start: ch.startTime,
                    end: ch.endTime,
                    duration: ch.endTime - ch.startTime,
                  }))
                )
              );
            }
          } else {
            // New format uses percentage directly; the 1.0002 factor offsets accumulating
            // rounding error across chapters.
            let index = 0;
            chapterElements.forEach((chapter) => {
              const width = parseFloat(chapter.style.width) || 0;
              const chapterDuration = (width / 100) * videoDuration * 1.0002;

              const startTime = currentTime;
              const isLastChapter = index === chapterElements.length - 1;
              const endTime = isLastChapter ? videoDuration : currentTime + chapterDuration;

              youtubeChapters.push({
                startTime,
                endTime,
                element: chapter,
              });

              currentTime = endTime;
              index++;
            });
          }

          return youtubeChapters;
        }

        // Two intervals overlap if the start of one is before the end of the other;
        // ERROR_MARGIN absorbs floating point / timing noise at the boundaries.
        function findOverlappingChapters(
          youtubeChapter,
          customChapters,
          totalDuration
        ) {
          const ERROR_MARGIN = totalDuration * 0.02;

          const MIN_OVERLAP_PERCENTAGE = 0.1;
          const MIN_OVERLAP_SECONDS = Math.max(2, totalDuration * 0.003);

          let overlappingChapters = [];

          for (const chapter of customChapters) {
            if (
              youtubeChapter.startTime - ERROR_MARGIN <= chapter.endTime &&
              youtubeChapter.endTime + ERROR_MARGIN >= chapter.startTime
            ) {
              const overlapStart = Math.max(
                youtubeChapter.startTime,
                chapter.startTime
              );
              const overlapEnd = Math.min(youtubeChapter.endTime, chapter.endTime);

              const ytChapterDuration = youtubeChapter.endTime - youtubeChapter.startTime;
              const overlapDuration = overlapEnd - overlapStart;
              const overlapPercentage = overlapDuration / ytChapterDuration;

              if (
                overlapPercentage > MIN_OVERLAP_PERCENTAGE &&
                overlapDuration > MIN_OVERLAP_SECONDS
              ) {
                overlappingChapters.push({
                  chapter: chapter,
                  overlapStart: overlapStart,
                  overlapEnd: overlapEnd,
                  overlapPercentage: overlapPercentage,
                });
              }
            }
          }

          return overlappingChapters;
        }

        if (typeof window.chapterRetryTimeoutId === "undefined") {
          window.chapterRetryTimeoutId = null;
        }

        function addYouTubeChapterMarkersWithRetry(
          chapters,
          videoDuration,
          retryIntervals,
          retryIndex = 0
        ) {
          if (window.chapterRetryTimeoutId !== null) {
            clearTimeout(window.chapterRetryTimeoutId);
            window.chapterRetryTimeoutId = null;
          }

          const { progressBar, isNewEmbedding, hasYoutubeChapters, chapterFormat } =
            findYouTubeProgressBar();

          if (!progressBar) {
            if (retryIndex < retryIntervals.length) {
              window.chapterRetryTimeoutId = setTimeout(() => {
                window.chapterRetryTimeoutId = null;
                addYouTubeChapterMarkersWithRetry(
                  chapters,
                  videoDuration,
                  retryIntervals,
                  retryIndex + 1
                );
              }, retryIntervals[retryIndex]);
            } else {
              const oldChaptersExists = document.querySelector(".ytp-chapters-container") !== null;
              const newChaptersExists = document.querySelector(".ytChapteredProgressBarHost") !== null;
              const anyProgressBar = document.querySelector(".ytp-progress-list") !== null ||
                                    document.querySelector(".ytProgressBarLineHost") !== null;

              if (window.enableLogging) {
                sendMessage(
                  "setChapterMarker Error",
                  JSON.stringify({
                    message: "YouTube progress bar not found after retries",
                    oldChaptersExists,
                    newChaptersExists,
                    anyProgressBar,
                  })
                );
              }
            }
            return;
          } else {
            if (window.enableLogging) {
              sendMessage("setChapterMarker Retries", retryIndex);
              sendMessage("hasYoutubeChapters", hasYoutubeChapters ? "true" : "false");
              if (hasYoutubeChapters) {
                sendMessage("chapterFormat", chapterFormat || "unknown");
              }
            }
          }

          removeCustomChapterAreas();

          if (hasYoutubeChapters) {
            const youtubeChapters = extractYouTubeChapters(progressBar, videoDuration, chapterFormat);

            if (youtubeChapters && youtubeChapters.length > 0) {
              youtubeChapters.forEach((ytChapter) => {
                const overlappingChapters = findOverlappingChapters(
                  ytChapter,
                  chapters,
                  videoDuration
                );
                const inactiveOverlaps = overlappingChapters.filter(
                  (overlap) => !overlap.chapter.isActive
                );
                if (inactiveOverlaps.length > 0) {
                  ytChapter.element.style.position = "relative";

                  // A single inactive overlap covering most of the chapter (>90%) just
                  // fills the whole chapter instead of drawing a precise segment.
                  const singleLargeInactiveOverlap =
                    inactiveOverlaps.length === 1 &&
                    inactiveOverlaps[0].overlapPercentage > 0.9;

                  if (singleLargeInactiveOverlap) {
                    const overlay = document.createElement("div");
                    overlay.className = "custom-chapter-overlay";
                    overlay.style.position = "absolute";
                    overlay.style.left = "0";
                    overlay.style.top = "0";
                    overlay.style.width = "100%";
                    overlay.style.height = "100%";
                    overlay.style.backgroundColor = "rgba(0, 0, 0, 0.5)";
                    overlay.style.pointerEvents = "none";
                    if (chapterFormat === "old") {
                      overlay.style.zIndex = "39";
                    }

                    ytChapter.element.appendChild(overlay);
                  } else {
                    inactiveOverlaps.forEach((overlap) => {
                      const ytChapterDuration = ytChapter.endTime - ytChapter.startTime;
                      const leftPercent =
                        ((overlap.overlapStart - ytChapter.startTime) /
                          ytChapterDuration) *
                        100;
                      const widthPercent =
                        ((overlap.overlapEnd - overlap.overlapStart) /
                          ytChapterDuration) *
                        100;
                      const overlay = document.createElement("div");
                      overlay.className = "custom-chapter-overlay";
                      overlay.style.position = "absolute";
                      overlay.style.left = `${leftPercent}%`;
                      overlay.style.top = "0";
                      overlay.style.width = `${widthPercent}%`;
                      overlay.style.height = "100%";
                      overlay.style.backgroundColor = "rgba(0, 0, 0, 0.5)";
                      overlay.style.pointerEvents = "none";

                      if (chapterFormat === "old") {
                        overlay.style.zIndex = "39";
                      }
                      ytChapter.element.appendChild(overlay);
                    });
                  }
                }
              });
            }

            let overlapsFound = 0;
            youtubeChapters.forEach((ytChapter) => {
              overlapsFound += findOverlappingChapters(
                ytChapter,
                chapters,
                videoDuration
              ).length;
            });

            const chapterDetails = youtubeChapters.map((ch, idx) => {
              const rect = ch.element.getBoundingClientRect();
              const elementStyle = window.getComputedStyle(ch.element);

              return {
                index: idx,
                startTime: ch.startTime.toFixed(2),
                endTime: ch.endTime.toFixed(2),
                duration: (ch.endTime - ch.startTime).toFixed(2),
                width: ch.element.style.width,
                marginRight: ch.element.style.marginRight,
                computedWidth: rect.width,
                computedMargin: elementStyle.marginRight,
              };
            });

            if (window.enableLogging) {
              sendMessage(
                "setChapterMarker chapterMapping",
                JSON.stringify({
                  youtube: youtubeChapters.length,
                  custom: chapters.length,
                  overlaps: overlapsFound,
                  format: chapterFormat,
                  details: chapterFormat === "old" ? chapterDetails : null,
                })
              );
            }

            return youtubeChapters.length;
          }

          chapters.forEach((chapter) => {
            const area = createChapterArea(
              chapter,
              videoDuration,
              isNewEmbedding,
              hasYoutubeChapters
            );
            if (area) {
              progressBar.style.position = "relative";
              progressBar.appendChild(area);
            }
          });

          return chapters.length;
        }

        window.enableLogging = \(enableLogging ? "true" : "false");

        if (typeof window.chapterRetryTimeoutId !== 'undefined' && window.chapterRetryTimeoutId !== null) {
            clearTimeout(window.chapterRetryTimeoutId);
            window.chapterRetryTimeoutId = null;
        }

        addYouTubeChapterMarkersWithRetry(
            [\(chaptersData)],
            \(videoDuration),
            [300, 1000, 5000]
        );
        """
    }
    // swiftlint:enable function_body_length
}
