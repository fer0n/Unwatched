//
//  ShareViewController.swift
//  UnwatchedShareExtension
//
//  Receives a shared YouTube URL and lets the user queue/inbox/subscribe it directly against
//  the shared App Group data store — no hand-off to the main app, so the source app (Safari,
//  YouTube, …) never loses focus.
//

import UIKit
import SwiftUI
import UniformTypeIdentifiers
import OSLog
import UnwatchedShared

private let logger = Logger(subsystem: "com.pentlandFirth.Unwatched.share", category: "ShareExtension")

class ShareViewController: UIViewController {

    private let model = ShareCardModel()
    private var sharedURL: URL?

    override func viewDidLoad() {
        super.viewDidLoad()

        let hosting = UIHostingController(
            rootView: ShareCardView(
                model: model,
                onSelect: { [weak self] action in
                    self?.handle(action)
                },
                onConfirmRemember: { [weak self] alwaysUse in
                    self?.confirmRemember(alwaysUse)
                },
                onSetAutoAction: { [weak self] setting in
                    self?.setAutoAction(setting)
                },
                onToggleSubscribe: { [weak self] in
                    self?.toggleSubscribe()
                }
            )
        )
        addChild(hosting)
        hosting.view.frame = view.bounds
        hosting.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(hosting.view)
        hosting.didMove(toParent: self)

        Task { await detectLink() }
    }

    @MainActor
    private func detectLink() async {
        guard let url = await extractSharedURL() else {
            logger.error("no URL found in shared item")
            model.state = .noLink
            return
        }

        if YoutubeUrlParser.isContentUrl(url) {
            sharedURL = url
            if let autoAction {
                performAction(autoAction, showsConfirmation: true)
                return
            }
            model.state = .choosing(.video)
            if let youtubeId = YoutubeUrlParser.getYoutubeId(from: url) {
                model.videoPreview = SendableVideo(youtubeId: youtubeId, title: "", url: url)
                Task { await loadPreview(youtubeId: youtubeId) }
            }
        } else if YoutubeUrlParser.isChannelUrl(url) {
            sharedURL = url
            model.state = .choosing(.channel)
            Task { await loadChannelPreview(url: url) }
        } else {
            logger.error("not a YouTube link: \(url.absoluteString, privacy: .public)")
            model.state = .notYouTube
        }
    }

    /// Fetches the video info backing the "loading video preview" placeholders. Best-effort: on
    /// failure the placeholders are simply left in place — the action buttons work regardless.
    @MainActor
    private func loadPreview(youtubeId: String) async {
        do {
            guard let info = try await YoutubeDataAPI.getYtVideoInfo(youtubeId) else { return }
            model.videoPreview = info
        } catch {
            logger.error("failed to load share preview: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Fetches the channel/playlist's name, thumbnail (if already subscribed), and current
    /// subscribed status backing the channel preview. Best-effort: on failure the skeleton is
    /// simply left in place — the Subscribe button still works, it just can't show a name yet.
    @MainActor
    private func loadChannelPreview(url: URL) async {
        let actor = ShareSubscribeActor(modelContainer: DataProvider.shared.container)
        guard let preview = await actor.preview(url: url) else {
            logger.error("failed to load channel preview")
            return
        }
        model.channelPreview = preview.subscription
        model.isSubscribed = preview.isSubscribed

        // Not already subscribed, so there's no synced thumbnail yet — fetch the channel's real
        // avatar so the preview doesn't just show a placeholder person icon.
        guard preview.subscription.thumbnailUrl == nil,
              let channelId = preview.subscription.youtubeChannelId else { return }
        do {
            guard let avatarURL = try await ChannelAvatarService.fetchAvatarURL(channelId: channelId) else { return }
            var updated = preview.subscription
            updated.thumbnailUrl = avatarURL
            model.channelPreview = updated
        } catch {
            logger.error("failed to load channel avatar: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// The action to perform without ever showing the chooser, based on the user's remembered
    /// preference — nil while `.askEveryTime` (the default).
    private var autoAction: ShareAction? {
        switch ShareExtensionSettings.action {
        case .askEveryTime: return nil
        case .play: return .play
        case .queueNext: return .queueNext
        case .queueLast: return .queueLast
        case .addToInbox: return .addToInbox
        }
    }

    // MARK: - Performing the action

    private func handle(_ action: ShareAction) {
        guard !ShareExtensionSettings.hasAskedToRemember else {
            performAction(action)
            return
        }
        model.pendingRememberPrompt = action
    }

    /// Answers the one-time "always use this action?" prompt shown the first time ever an action
    /// is picked, then performs that (now-answered-for) action.
    private func confirmRemember(_ alwaysUse: Bool) {
        guard let action = model.pendingRememberPrompt else { return }
        ShareExtensionSettings.hasAskedToRemember = true
        if alwaysUse {
            ShareExtensionSettings.action = action.settingCase
        }
        model.pendingRememberPrompt = nil
        performAction(action)
    }

    /// Remembers `setting` as the action to auto-perform on future shares (from the "…" menu),
    /// and immediately performs the matching action for the video being shared right now.
    private func setAutoAction(_ setting: ShareExtensionActionSetting) {
        ShareExtensionSettings.action = setting
        ShareExtensionSettings.hasAskedToRemember = true
        switch setting {
        case .askEveryTime: break
        case .play: performAction(.play)
        case .queueNext: performAction(.queueNext)
        case .queueLast: performAction(.queueLast)
        case .addToInbox: performAction(.addToInbox)
        }
    }

    /// Performs `action`. `showsConfirmation` is only set when auto-select skipped the chooser
    /// entirely — without it, going straight from sharing to the extension closing itself looks
    /// broken, so a brief checkmark confirmation shows first. Manual taps on the chooser's buttons
    /// close immediately instead, since the button itself was already the confirmation.
    private func performAction(_ action: ShareAction, showsConfirmation: Bool = false) {
        guard let url = sharedURL else { return }
        if action == .play {
            openInApp(url)
            return
        }
        model.loadingAction = action
        Task { @MainActor in
            do {
                let message = try await perform(action, url: url)
                if showsConfirmation {
                    model.loadingAction = nil
                    model.state = .done(message)
                    await sleep(0.5)
                }
                finish()
            } catch {
                logger.error("share action failed: \(error.localizedDescription, privacy: .public)")
                model.loadingAction = nil
                model.state = .error(String(localized: "Something went wrong"))
            }
        }
    }

    /// Hands off to the main app via its `unwatched://play` deep link, which both queues and
    /// starts playback — same code path as Shortcuts/"paste and play".
    ///
    /// `extensionContext?.open(_:completionHandler:)` looks like the sanctioned way to do this,
    /// but Apple documents it as working only from Today widgets — share extensions silently fail
    /// (rdar://17551744). The legacy `openURL:` selector is now hard-blocked by UIKit for
    /// extensions too (force-returns NO), so `launchContainingApp` reaches the host `UIApplication`
    /// through the responder chain and invokes the modern `open(_:options:completionHandler:)`
    /// through the Obj-C runtime instead, falling back to `extensionContext.open` if that's
    /// unavailable.
    private func openInApp(_ url: URL) {
        var components = URLComponents()
        components.scheme = "unwatched"
        components.host = "play"
        components.queryItems = [
            URLQueryItem(name: "url", value: url.absoluteString),
            URLQueryItem(name: "source", value: "share_extension")
        ]
        guard let deepLink = components.url else { return }
        launchContainingApp(deepLink)

        Task { @MainActor in
            // Give the system time to act on the open request before tearing down.
            await sleep(0.3)
            finish()
        }
    }

    /// Opens `url` to launch the containing app, preferring the host `UIApplication`
    /// (reached via the responder chain) and falling back to the extension context.
    private func launchContainingApp(_ url: URL) {
        if hostApplication?.openFromExtension(url, completion: logOpenResult) == true {
            return
        }
        extensionContext?.open(url, completionHandler: logOpenResult)
    }

    /// The host process's `UIApplication`, reachable through the responder chain in an extension.
    private var hostApplication: UIApplication? {
        sequence(first: self as UIResponder, next: { $0.next })
            .first { $0 is UIApplication } as? UIApplication
    }

    private func logOpenResult(_ success: Bool) {
        if !success { logger.error("failed to open containing app") }
    }

    private func sleep(_ seconds: TimeInterval) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    private func perform(_ action: ShareAction, url: URL) async throws -> String {
        let actor = ShareAddActor(modelContainer: DataProvider.shared.container)
        switch action {
        case .play:
            preconditionFailure("play is handled directly in handle(_:) and never reaches perform")
        case .queueNext:
            try await actor.addForeignUrls([url], in: .queue, at: 1, markAsNew: false)
            return String(localized: "Playing Next")
        case .queueLast:
            try await actor.addForeignUrls([url], in: .queue, at: -1, markAsNew: false)
            return String(localized: "Playing Last")
        case .addToInbox:
            try await actor.addForeignUrls([url], in: .inbox, at: 0, markAsNew: false)
            return String(localized: "Added to Inbox")
        }
    }

    /// Toggles the shared channel/playlist's subscription — the capsule button stays visible and
    /// shows a spinner while this runs, same as `ChannelPreviewView`'s Subscribe/Subscribed button
    /// in the main app; the share sheet itself stays open either way.
    private func toggleSubscribe() {
        guard let url = sharedURL else { return }
        model.isTogglingSubscription = true
        Task { @MainActor in
            defer { model.isTogglingSubscription = false }
            let actor = ShareSubscribeActor(modelContainer: DataProvider.shared.container)
            do {
                if model.isSubscribed {
                    await actor.unsubscribe(url: url)
                    model.isSubscribed = false
                } else {
                    _ = try await actor.subscribe(to: url)
                    model.isSubscribed = true
                }
            } catch {
                logger.error("subscribe toggle failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: - Extracting the URL

    private func extractSharedURL() async -> URL? {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else { return nil }
        let providers = items.flatMap { $0.attachments ?? [] }

        // Prefer an explicit URL attachment (YouTube app, Safari share a public.url).
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            if let url = await loadURL(from: provider, type: UTType.url.identifier) {
                return url
            }
        }

        // Fall back to plain text that contains a URL (some apps share "… https://youtu.be/…").
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            if let url = await loadURL(from: provider, type: UTType.plainText.identifier) {
                return url
            }
        }

        return nil
    }

    private func loadURL(from provider: NSItemProvider, type: String) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: type, options: nil) { item, _ in
                continuation.resume(returning: Self.url(from: item))
            }
        }
    }

    private static func url(from item: NSSecureCoding?) -> URL? {
        switch item {
        case let url as URL:
            return url
        case let string as String:
            return firstURL(in: string)
        case let data as Data:
            if let string = String(data: data, encoding: .utf8) {
                return URL(string: string) ?? firstURL(in: string)
            }
            return nil
        default:
            return nil
        }
    }

    private static func firstURL(in text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..., in: text)
        return detector?.firstMatch(in: text, range: range)?.url
    }

    // MARK: - Dismissal

    private func finish() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}

private extension UIApplication {
    /// Opens `url` from inside an app extension.
    ///
    /// `open(_:options:completionHandler:)` is unavailable to extensions at compile time, and the
    /// legacy `openURL:` is now hard-blocked by UIKit (force-returns NO), so we invoke the modern
    /// method through the Obj-C runtime. Returns `false` if it isn't available, so the caller can
    /// fall back to `NSExtensionContext.open`.
    @discardableResult
    func openFromExtension(_ url: URL, completion: @escaping (Bool) -> Void) -> Bool {
        let selector = NSSelectorFromString("openURL:options:completionHandler:")
        guard responds(to: selector) else { return false }

        typealias OpenURL = @convention(c)
            (NSObject, Selector, NSURL, NSDictionary, @escaping (Bool) -> Void) -> Void
        let open = unsafeBitCast(method(for: selector), to: OpenURL.self)
        open(self, selector, url as NSURL, NSDictionary(), completion)
        return true
    }
}
