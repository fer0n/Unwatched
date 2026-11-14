// Mirrors Const.settingsDefaults / syncedSettingsDefaults (AppConstants.swift) by hand, defaults
// included: users missing from a snapshot are counted on the default. See CLAUDE.md.
export const BOOL_SETTINGS = [
  // Notifications
  ["videoAddedToInboxNotification", false, "Notify: Inbox"],
  ["videoAddedToQueueNotification", false, "Notify: Queue"],
  ["showNotificationBadge", false, "Notification Badge"],
  // General
  ["autoClearNew", false, "Auto-clear \"New\""],
  ["refreshOnStartup", true, "Refresh on Startup"],
  ["requireClearConfirmation", true, "Require Clear Confirmation"],
  ["showClearQueueButton", true, "Show Clear-Queue Button"],
  ["showSearchYoutubeButton", true, "Search: YouTube Button"],
  ["autoFocusSearch", true, "Search: Auto-Focus"],
  ["showRecentSearches", true, "Search: Recent Searches"],
  ["showSearchRecommendations", false, "Search: Recommendations"],
  ["enableQueueContextMenu", false, "Queue Context Menu"],
  ["autoRefreshIgnoresSync", false, "Auto-refresh Ignores Sync"],
  ["useNoCookieUrl", false, "Use No-Cookie URL"],
  ["quickSwitchAllVideos", true, "Quick Switch: All Videos"],
  // Playback
  ["preferPlayerType", false, "Prefer Player Type"],
  ["originalAudio", true, "Original Audio"],
  ["trimSilence", false, "Trim Silence"],
  ["backgroundPlayback", true, "Background Playback"],
  ["hideMenuOnPlay", true, "Hide Menu on Play"],
  ["returnToQueue", true, "Return to Queue"],
  ["rotateOnPlay", false, "Rotate on Play"],
  ["markWatchedOnEnded", true, "Mark Watched on Ended"],
  ["playVideoFullscreen", false, "Play Fullscreen"],
  ["disableCaptions", false, "Disable Captions"],
  ["autoCaptionsOnSeekBack", false, "Auto-captions on Seek Back"],
  ["customUICaptions", false, "Custom UI Captions"],
  ["swipeGestureUp", true, "Swipe Gesture: Up"],
  ["swipeGestureDown", true, "Swipe Gesture: Down"],
  ["swipeGestureLeft", true, "Swipe Gesture: Left"],
  ["swipeGestureRight", true, "Swipe Gesture: Right"],
  ["autoAirplayHD", false, "Auto AirPlay HD"],
  ["suggestVideos", false, "Suggest Videos"],
  ["nativePlayerFallback", true, "Native Player Fallback"],
  ["playBrowserVideosInApp", true, "Play Browser Videos In-App"],
  ["copyAppUrl", false, "Copy App URL"],
  ["surroundingEffect", true, "Surrounding Effect"],
  // Appearance
  ["showTabBarBadge", true, "Show Tab Bar Badge"],
  ["hidePlayerPageIndicator", false, "Hide Player Page Indicator"],
  ["inboxOldestFirst", false, "Inbox Oldest First"],
  ["lightAppIcon", false, "Light App Icon"],
  // Filter (synced)
  ["autoSkipRecurringChapters", true, "Auto-skip Recurring Chapters"],
  ["allowOnMatch", false, "Allow on Match"],
  ["mergeSponsorBlockChapters", false, "Merge SponsorBlock Chapters"],
  ["youtubePremium", false, "YouTube Premium"],
  // User data
  ["enableIcloudSync", false, "iCloud Sync"],
  ["automaticBackups", true, "Automatic Backups"],
  ["includeWatchHistoryInBackup", true, "Backup: Watch History"],
  ["includeUnimportantVideosInBackup", false, "Backup: Unimportant Videos"],
  ["autoDeleteBackups", true, "Auto-delete Backups"],
  // Podcasts
  ["firstPodcastAdded", false, "Has Added a Podcast"],
  ["podcastDownloadOnCellular", false, "Podcast Downloads on Cellular"],
  // Chapters
  ["chapterShortcutAutomation", false, "Chapter Shortcut Automation"],
  // Premium
  ["unwatchedPremiumAcknowledged", false, "Premium Unlocked"],
  ["hidePremium", false, "Hide Premium"],
  // Presence-only flags for free-text settings — the values themselves are never sent
  // (see SetupView.sendSettings / getNonDefaultSettings).
  ["hasCustomApiKey", false, "Custom API Key Set"],
  ["hasSkipText", false, "Skip-Chapter Text Set"],
];

// Same contract as BOOL_SETTINGS. [key, default, label, rawValue labels or null for numbers, unit]
export const VALUE_SETTINGS = [
  ["defaultVideoPlacement", 0, "Default Video Placement",
    { 0: "Inbox", 1: "Queue next", 4: "Queue last", 2: "Nothing", 3: "Default" }],
  ["defaultShortsSetting", 2, "Shorts", { 0: "Show", 1: "Hide", 2: "Default" }],
  ["defaultLiveStreamSetting", 0, "Live Streams", { 0: "Show", 1: "Hide", 2: "Default" }],
  ["inboxAppearance", 1, "Inbox Appearance", { 0: "List", 1: "Cards" }],
  ["videoListFormat", 0, "Video List Format", { 0: "Compact", 1: "Expansive" }],
  ["browserDisplayMode", 0, "Browser", { 0: "In-app", 1: "In-app (old sheet)", 3: "External", 2: "Disabled" }],
  ["fullscreenControlsSetting", 1, "Fullscreen Controls", { 0: "Enabled", 1: "Auto-hide", 2: "Disabled" }],
  ["sponsorSegmentSetting", 1, "SponsorBlock: Sponsor", { 0: "Off", 1: "Show", 2: "Show & skip" }],
  ["selfPromoSegmentSetting", 1, "SponsorBlock: Self-promo", { 0: "Off", 1: "Show", 2: "Show & skip" }],
  // 2 is the old "dark" from before the light option was removed (AppAppearance shifted
  // dark from 2 to 1). The app can't decode it and falls back to the default.
  ["lightModeTheme", 0, "Light Mode Theme", { 0: "Unwatched", 1: "Dark", 2: "Old dark (reads as Unwatched)" }],
  ["darkModeTheme", 1, "Dark Mode Theme", { 0: "Unwatched", 1: "Dark", 2: "Old dark (reads as Dark)" }],
  ["themeColor", 6, "Theme Color", {
    0: "Red", 1: "Orange", 2: "Yellow", 3: "Green", 4: "Dark green",
    5: "Mint", 6: "Teal", 7: "Blue", 8: "Purple", 9: "Black/White",
  }],
  ["playbackSpeed", 1, "Playback Speed", null, "×"],
  ["temporarySpeedUp", 2, "Temporary Speed Up", null, "×"],
  ["temporarySlowDown", 0.6, "Temporary Slow Down", null, "×"],
  ["doubleTapSeekDuration", 10, "Double-tap Seek", null, "s"],
  ["autoDeleteWatchedVideos", 180, "Auto-delete Watched", null, "d"],
  ["autoDeleteOrphanedVideos", 30, "Auto-delete Orphaned", null, "d"],
  ["autoDeleteInboxVideosLimit", 100, "Inbox Limit", null, ""],
  ["podcastDownloadLimitHours", 5, "Podcast Download Limit", null, "h"],
  ["podcastDownloadKeepDays", 1, "Podcast Keep", null, "d"],
  ["podcastDownloadCellularHours", 0, "Podcast Cellular Limit", null, "h"],
  ["maxAutoTranscriptions", 2, "Max Auto-transcriptions", null, ""],
];

export const SETTINGS_VALUE_PREFIX = "Unwatched.Setting.";

// [key, label] — mirrors SubscriptionActor.getSubscriptionSettingCounts, see CLAUDE.md.
export const SUBSCRIPTION_SETTINGS = [
  ["speed", "Speed"],
  ["placement", "Video placement"],
  ["episodeLimit", "Episode limit"],
  ["shorts", "Shorts"],
  ["liveStreams", "Live streams"],
  ["skipIntro", "Skip intro"],
  ["skipOutro", "Skip outro"],
  ["autoSkip", "Auto-skip chapters"],
  ["sponsor", "SponsorBlock: Sponsor"],
  ["selfPromo", "SponsorBlock: Self-promo"],
  ["chapterGeneration", "Chapter generation"],
  ["titleFilter", "Title filter"],
];
