//
//  YoutubeCookieFilterTests.swift
//  UnwatchedUITests
//

import XCTest
import UnwatchedShared

final class YoutubeCookieFilterTests: XCTestCase {
    private func cookie(
        _ name: String,
        domain: String = ".youtube.com",
        httpOnly: Bool = false,
        expires: Date? = nil
    ) -> HTTPCookie {
        var props: [HTTPCookiePropertyKey: Any] = [
            .name: name,
            .value: "value-for-\(name)",
            .domain: domain,
            .path: "/",
            .secure: "TRUE",
            .version: "1"
        ]
        if let expires {
            props[.expires] = expires
        }
        if httpOnly {
            props[HTTPCookiePropertyKey("HttpOnly")] = "TRUE"
        }
        return HTTPCookie(properties: props)!
    }

    private var sampleJar: [HTTPCookie] {
        [
            cookie("LOGIN_INFO", httpOnly: true, expires: Date(timeIntervalSinceNow: 3600)),
            cookie("SID", domain: ".google.com"),
            cookie("__Secure-3PSID"),
            cookie("SAPISID"),
            cookie("VISITOR_INFO1_LIVE"),
            cookie("YSC"),
            cookie("SOCS"),
            cookie("PREF"),
            cookie("__Secure-YNID"),
            cookie("rqh", domain: "rr3---sn-abc.googlevideo.com")
        ]
    }

    func testFilterKeepsOnlyTheAnonymousCookies() {
        let names = Set(YoutubeCookieFilter.sharable(sampleJar).map(\.name))
        XCTAssertEqual(names, ["VISITOR_INFO1_LIVE", "YSC", "SOCS", "PREF", "rqh"])
    }

    func testFilterKeepsCdnCookiesWhateverTheyAreCalled() {
        XCTAssertTrue(
            YoutubeCookieFilter.isSharable(cookie("some-new-cdn-cookie", domain: "rr1---sn-xyz.googlevideo.com"))
        )
    }

    func testUnknownCookiesAreNeverSharable() {
        XCTAssertFalse(YoutubeCookieFilter.isSharable(cookie("session", domain: ".example.com")))
        XCTAssertFalse(YoutubeCookieFilter.isSharable(cookie("__Secure-SOME-NEW-SID")))
    }
}
