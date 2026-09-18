//
//  ShareExtensionSignal.swift
//  UnwatchedShareExtension
//

import Foundation
import UnwatchedShared

/// A minimal, self-contained analytics send for the share extension. It can't reuse `Signal`
/// (which calls `UIApplication.shared`, a compile error in this `APPLICATION_EXTENSION_API_ONLY`
/// target) or `AnalyticsQueue` (its on-disk queue lives in the app's own sandbox, not shared, and
/// batches for a long-lived process this extension never is) — so one event per invocation, sent
/// immediately and best-effort, matching the very low, bursty volume here.
enum ShareExtensionSignal {
    /// Unidentified on purpose: the extension has no access to the app's per-install
    /// `anonymousUserId` (a different sandbox), and reach isn't the point here — which action
    /// gets used is.
    static func logAdd(_ action: ShareAction) async {
        guard AnalyticsSettings.isEnabled else { return }
        let actionName: String
        switch action {
        case .play: actionName = "play"
        case .queueNext: actionName = "queueNext"
        case .queueLast: actionName = "queueLast"
        case .addToInbox: actionName = "addToInbox"
        }
        await send(name: "ShareExtension.Add", params: ["action": actionName])
    }

    private static func send(name: String, params: [String: String]) async {
        guard let url = URL(string: Credentials.analyticsEndpoint) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(Credentials.analyticsSecret)", forHTTPHeaderField: "Authorization")
        let event: [String: Any] = [
            "name": name,
            "params": params,
            "clientTimestamp": Date().timeIntervalSince1970 * 1000,
            "channel": BuildInfo.channel,
            "appVersion": BuildInfo.version
        ]
        guard let body = try? JSONSerialization.data(withJSONObject: ["events": [event]]) else { return }
        request.httpBody = body
        _ = try? await URLSession.app.data(for: request)
    }
}
