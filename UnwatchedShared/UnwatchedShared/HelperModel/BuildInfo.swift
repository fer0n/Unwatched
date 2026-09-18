//
//  BuildInfo.swift
//  UnwatchedShared
//

import Foundation

/// Which build produced something, and its version — usable from any process, including
/// `UnwatchedShareExtension`, unlike `Signal` itself (which needs `UIApplication`).
/// `Bundle.main` resolves per-process, so this correctly reflects the extension's own build
/// when read from there, not the host app's.
public enum BuildInfo {
    public static var isTestFlight: Bool {
        Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
    }

    /// See `Signal.buildChannel` for why this rides along on every analytics event.
    public static var channel: String {
        #if DEBUG
        return "debug"
        #else
        return isTestFlight ? "testflight" : "release"
        #endif
    }

    /// e.g. "2.0.1", with the build number appended off release.
    public static let version: String = {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        #if DEBUG
        let includeBuild = true
        #else
        let includeBuild = isTestFlight
        #endif
        guard includeBuild, let build = info?["CFBundleVersion"] as? String else {
            return version
        }
        return "\(version) (\(build))"
    }()
}
