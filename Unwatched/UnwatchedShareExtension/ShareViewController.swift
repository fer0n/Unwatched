//
//  ShareViewController.swift
//  UnwatchedShareExtension
//
//  Receives a shared YouTube URL and hands it off to the main app via the
//  existing `unwatched://queue?url=…` deep link — the same path used by the
//  AddYoutubeURL App Intent. Shows a minimal confirmation card and dismisses
//  as quickly as possible.
//

import UIKit
import SwiftUI
import UniformTypeIdentifiers
import OSLog
import UnwatchedShared

private let logger = Logger(subsystem: "com.pentlandFirth.Unwatched.share", category: "ShareExtension")

class ShareViewController: UIViewController {

    /// Minimum time the card stays visible so the hand-off doesn't feel like a flicker.
    private let minimumDisplay: TimeInterval = 0.4

    private let model = ShareCardModel()

    override func viewDidLoad() {
        super.viewDidLoad()

        let hosting = UIHostingController(rootView: ShareCardView(model: model))
        hosting.view.backgroundColor = .clear
        addChild(hosting)
        hosting.view.frame = view.bounds
        hosting.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(hosting.view)
        hosting.didMove(toParent: self)

        Task { await handleShare() }
    }

    @MainActor
    private func handleShare() async {
        async let minDelay: Void = sleep(minimumDisplay)

        guard let url = await extractSharedURL() else {
            logger.error("no URL found in shared item")
            await minDelay
            model.state = .noLink
            await sleep(1.2)
            finish()
            return
        }

        guard YoutubeUrlParser.isContentUrl(url) else {
            logger.error("not a YouTube video/playlist URL: \(url.absoluteString, privacy: .public)")
            await minDelay
            model.state = .notYouTube
            await sleep(1.2)
            finish()
            return
        }

        model.state = .added
        await minDelay
        openMainApp(with: url)
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

    // MARK: - Hand-off

    private func openMainApp(with videoURL: URL) {
        var components = URLComponents()
        components.scheme = "unwatched"
        components.host = "queue"
        components.queryItems = [
            URLQueryItem(name: "url", value: videoURL.absoluteString),
            URLQueryItem(name: "next", value: "true")
        ]

        guard let deepLink = components.url else {
            finish()
            return
        }

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

    private func finish() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    private func sleep(_ seconds: TimeInterval) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
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
