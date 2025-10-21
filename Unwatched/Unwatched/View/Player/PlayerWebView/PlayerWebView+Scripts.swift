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
        webView.load(request)
        return true
    }

    func getPlayScript() -> String {
        if player.unstarted {
            Log.info("PLAY: unstarted")
            return """
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
                                // workaround: click seems to happen too fast with nocookie url
                                // no other way of awaiting loading worked. Using this sometimes led to the
                                // regular player being stuck with YouTube's loading indicator
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

                // theater mode - workaround: using setTimeout on macOS leads to auto play in some cases
                if (!(video?.offsetWidth >= window.innerWidth * 0.98)) {
                    const theaterButton = document.querySelector(".ytp-size-button");
                    if (theaterButton) {
                        theaterButton.click();
                    }
                }
            """
        }
        return "play();"
    }

    func getPauseScript() -> String {
        """
        video.pause();
        """
    }

    func getSeekToScript(_ seekTo: Double) -> String {
        """
        video.currentTime = \(seekTo);
        startAtTime = \(seekTo);
        """
    }

    func getSeekRelScript(_ seekRel: Double) -> String {
        """
        if (video.duration) {
            video.currentTime = Math.min(video.currentTime + \(seekRel), video.duration - 0.2);
        } else {
            video.currentTime += \(seekRel);
        }
        """
    }

    func getSetPlaybackRateScript() -> String {
        "video.playbackRate = \(player.playbackSpeed);"
    }

    func getEnterPipScript() -> String {
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

    func getExitPipScript() -> String {
        "document.exitPictureInPicture();"
    }

    // Sometimes on iOS 26, the player is black and unresponsive
    // changing quality fixes it
    // should only trigger when the video is there, but not working
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

    /// Override YouTube chapter indicators with custom chapters
    // swiftlint:disable function_body_length
    static func setChapterMarkersScript(
        chapters: [Chapter],
        videoDuration: Double,
        enableLogging: Bool) -> String {
        // Convert chapters to a JSON array of objects with startTime, endTime and isActive properties
        let chaptersData = chapters.map { chapter in
            """
            {
            "startTime": \(chapter.startTime),
            "endTime": \(chapter.endTime ?? -1),
            "isActive": \(chapter.isActive)
            }
            """
        }.joined(separator: ", ")

        return """
        function findYouTubeProgressBar() {
          // First check for the new YouTube chapters progress bar
          let chapteredProgressBar = document.querySelector(
            ".ytChapteredProgressBarHost"
          );
          if (chapteredProgressBar) {
            // Only accept the chaptered progress bar if it actually contains chapter elements
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

          // Check for older embedded player chapters container
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

          // Then check for regular progress bars
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

          // If we have YouTube chapters and this chapter is inactive, just show the overlay
          // Otherwise show the chapter markers for non-YouTube chaptered videos
          if (hasYoutubeChapters) {
            area.style.borderLeft = ""; // No border when using YouTube's native chapters
            area.style.backgroundColor = chapter.isActive
              ? "transparent"
              : "rgba(0, 0, 0, 0.5)";
            area.style.zIndex = "36"; // Consistent with overlays in old embedded player
          } else {
            area.style.borderLeft = "2px solid rgba(0, 0, 0, 0.7)";
            area.style.backgroundColor = chapter.isActive
              ? "transparent"
              : "rgba(0, 0, 0, 0.5)";
          }

          return area;
        }

        // Extract chapter information from YouTube's native chapter elements
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

          // Verify that chapters are properly loaded
          let hasValidChapters = false;

          if (chapterFormat === "old") {
            // For old format, having elements is usually enough as they're created
            // with proper widths when the player initializes
            hasValidChapters = chapterElements.length > 1;

            // Additional check: sum of widths should be significant
            let totalWidthCheck = 0;
            for (let i = 0; i < chapterElements.length; i++) {
              totalWidthCheck += parseFloat(chapterElements[i].style.width) || 0;
            }

            // If we have multiple chapters but their widths don't add up to anything significant,
            // something might be wrong with the chapter data
            if (hasValidChapters && totalWidthCheck < 10) {
              if (window.enableLogging) {
                sendMessage("setChapterMarker", "Chapter elements found but widths are too small");
              }
              hasValidChapters = false;
            }
          } else {
            // For new format, check if at least one chapter has a valid width
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

          // For old format, we need to handle the calculation differently
          if (chapterFormat === "old") {
            // First, get the actual progress bar width
            const progressBarWidth = progressBar.getBoundingClientRect().width;

            // We need to examine the structure of .ytp-chapters-container
            // In the old format, each chapter's width represents its proportion of the total video
            let sumWidth = 0;
            let useClientRect = false;

            // First try to use style.width
            chapterElements.forEach((chapter) => {
              const width = parseFloat(chapter.style.width) || 0;
              // Account for margin-right if present (typically 2px in the old format)
              const marginRight = parseFloat(chapter.style.marginRight) || 0;
              sumWidth += width + marginRight;
            });

            // If the sumWidth seems too small, fall back to getBoundingClientRect
            if (sumWidth < 20) {
              sumWidth = 0;
              useClientRect = true;
              chapterElements.forEach((chapter) => {
                const rect = chapter.getBoundingClientRect();
                const width = rect.width;
                // We still need to account for the margin between chapters
                const style = window.getComputedStyle(chapter);
                const marginRight = parseFloat(style.marginRight) || 0;
                sumWidth += width + marginRight;
              });
            }

            // Now calculate each chapter's duration based on its proportion of the total width
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

              // Calculate this chapter's duration as a proportion of the video duration
              const chapterDuration = (totalWidth / sumWidth) * videoDuration;

              // Apply small padding to account for accumulating rounding errors
              // The padding is relative to the chapter's position in the sequence and duration
              const startTime = runningTime;
              const isLastChapter = i === chapterElements.length - 1;
              // For the last chapter, make it end exactly at videoDuration to avoid gaps
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
            // For new format, use the original approach
            let index = 0;
            chapterElements.forEach((chapter) => {
              const width = parseFloat(chapter.style.width) || 0;
              // New format uses percentage directly
              // small padding to minimize accumulating errors
              const chapterDuration = (width / 100) * videoDuration * 1.0002;

              const startTime = currentTime;
              const isLastChapter = index === chapterElements.length - 1;
              // For the last chapter, make it end exactly at videoDuration to avoid gaps
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

        // Find all custom chapters that overlap with a YouTube chapter
        function findOverlappingChapters(
          youtubeChapter,
          customChapters,
          totalDuration
        ) {
          // Allow for small timing differences (2% of video duration)
          const ERROR_MARGIN = totalDuration * 0.02;

          // Minimum overlap percentage to be considered meaningful
          const MIN_OVERLAP_PERCENTAGE = 0.1;
          const MIN_OVERLAP_SECONDS = Math.max(2, totalDuration * 0.003); // At least 2 seconds or 0.3% of duration

          // Find all chapters that overlap with this YouTube chapter
          let overlappingChapters = [];

          for (const chapter of customChapters) {
            // Check if there's any overlap between the YouTube chapter and this custom chapter
            // Two intervals overlap if start of one is less than end of the other
            // Add error margin to avoid false overlaps due to floating point precision
            if (
              youtubeChapter.startTime - ERROR_MARGIN <= chapter.endTime &&
              youtubeChapter.endTime + ERROR_MARGIN >= chapter.startTime
            ) {
              // Calculate the overlapping region
              const overlapStart = Math.max(
                youtubeChapter.startTime,
                chapter.startTime
              );
              const overlapEnd = Math.min(youtubeChapter.endTime, chapter.endTime);

              // Calculate overlap as a percentage of the YouTube chapter
              const ytChapterDuration = youtubeChapter.endTime - youtubeChapter.startTime;
              const overlapDuration = overlapEnd - overlapStart;
              const overlapPercentage = overlapDuration / ytChapterDuration;

              // Only include if there's a meaningful overlap - either percentage or absolute time based
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

        // Global variable to track the current retry timeout
        if (typeof window.chapterRetryTimeoutId === "undefined") {
          window.chapterRetryTimeoutId = null;
        }

        function addYouTubeChapterMarkersWithRetry(
          chapters,
          videoDuration,
          retryIntervals,
          retryIndex = 0
        ) {
          // Clear any existing timeout to cancel previous retry attempts
          if (window.chapterRetryTimeoutId !== null) {
            clearTimeout(window.chapterRetryTimeoutId);
            window.chapterRetryTimeoutId = null;
          }

          const { progressBar, isNewEmbedding, hasYoutubeChapters, chapterFormat } =
            findYouTubeProgressBar();

          if (!progressBar) {
            if (retryIndex < retryIntervals.length) {
              // Store the timeout ID so it can be cancelled if needed
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
              // Check for specific elements to provide better diagnostics
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
            // Extract YouTube's native chapters
            const youtubeChapters = extractYouTubeChapters(progressBar, videoDuration, chapterFormat);

            if (youtubeChapters && youtubeChapters.length > 0) {
              // Process each YouTube chapter and find overlapping custom chapters
              youtubeChapters.forEach((ytChapter) => {
                const overlappingChapters = findOverlappingChapters(
                  ytChapter,
                  chapters,
                  videoDuration
                );
                // Filter to just the inactive chapters
                const inactiveOverlaps = overlappingChapters.filter(
                  (overlap) => !overlap.chapter.isActive
                );
                if (inactiveOverlaps.length > 0) {
                  // Make sure the parent has position relative for absolute positioning of overlays
                  ytChapter.element.style.position = "relative";

                  // If there's only one inactive overlap and it covers most of the chapter (>90%),
                  // simply fill the entire chapter
                  const singleLargeInactiveOverlap =
                    inactiveOverlaps.length === 1 &&
                    inactiveOverlaps[0].overlapPercentage > 0.9;

                  if (singleLargeInactiveOverlap) {
                    // Create a full-width overlay
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

                    // Add the overlay as a child
                    ytChapter.element.appendChild(overlay);
                  } else {
                    // Create an overlay for each inactive segment
                    inactiveOverlaps.forEach((overlap) => {
                      // Calculate position and size of the overlay within the YouTube chapter
                      const ytChapterDuration = ytChapter.endTime - ytChapter.startTime;
                      const leftPercent =
                        ((overlap.overlapStart - ytChapter.startTime) /
                          ytChapterDuration) *
                        100;
                      const widthPercent =
                        ((overlap.overlapEnd - overlap.overlapStart) /
                          ytChapterDuration) *
                        100;
                      // Create an overlay element that covers just this inactive segment
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
                      // Add the overlay as a child
                      ytChapter.element.appendChild(overlay);
                    });
                  }
                }
              });
            }

            // Log the mapping for debugging
            let overlapsFound = 0;
            youtubeChapters.forEach((ytChapter) => {
              overlapsFound += findOverlappingChapters(
                ytChapter,
                chapters,
                videoDuration
              ).length;
            });

            // Detailed chapter diagnostics
            const chapterDetails = youtubeChapters.map((ch, idx) => {
              // Get the element's dimensions for debugging
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

          // Fallback to original implementation if no YouTube chapters or matching failed
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

        // Reset any existing timeouts before starting a new chapter marking process
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
}
