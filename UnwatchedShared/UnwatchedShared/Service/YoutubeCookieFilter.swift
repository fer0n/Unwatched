//
//  YoutubeCookieFilter.swift
//  UnwatchedShared
//

import Foundation

/// Decides which of the web view's cookies may be attached to the app's own requests.
/// Anything carrying account identity must not be: YouTube reads a session arriving without the
/// matching `SAPISIDHASH` as a stolen-cookie replay and invalidates the login days later.
public enum YoutubeCookieFilter {

    /// What anonymous playback needs. An allowlist because Google adds cookie names, and a
    /// denylist would leak silently the day they do. `__Secure-YNID` is deliberately absent —
    /// a leaked credential fails silently, a missing CDN cookie shows up as a 403.
    private static let anonymousNames: Set<String> = [
        "VISITOR_INFO1_LIVE",
        "VISITOR_PRIVACY_METADATA",
        "YSC",
        "PREF",
        "SOCS",
        "CONSENT",
        "GPS",
        "__Secure-ROLLOUT_TOKEN"
    ]

    /// CDN-set cookies always pass: no account identity, and `rqh=1` segments need them.
    public static func isSharable(_ cookie: HTTPCookie) -> Bool {
        cookie.isYoutubeCdnDomain || anonymousNames.contains(cookie.name)
    }

    public static func sharable(_ cookies: [HTTPCookie]) -> [HTTPCookie] {
        cookies.filter(isSharable)
    }
}
