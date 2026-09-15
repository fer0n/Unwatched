//
//  GapChapterLabelTests.swift
//  UnwatchedUITests
//

import XCTest
import UnwatchedShared

@MainActor
final class GapChapterLabelTests: XCTestCase {

    private func resolved(_ kind: GapLabel.Kind, _ title: String) -> (title: String?, category: ChapterCategory) {
        GapChapterService.resolve(GapLabel(kind: kind, title: title))
    }

    /// The catalog isn't in the test runner's bundle, so a localized value comes back as its key.
    /// Expectations are composed from the same lookup, which still pins the format.
    private var sponsorPrefix: String { String(localized: "categorySponsor") }

    private func rendered(_ resolved: (title: String?, category: ChapterCategory)) -> String? {
        SendableChapter(
            title: resolved.title,
            startTime: 0,
            endTime: 30,
            category: resolved.category
        ).titleText
    }

    func testAdvertisementBecomesASponsorChapter() {
        let result = resolved(.advertisement, "Squarespace")
        XCTAssertEqual(result.category, .sponsor)
        XCTAssertEqual(result.title, "Squarespace")
        XCTAssertEqual(rendered(result), "\(sponsorPrefix) Squarespace")
    }

    func testACategoryPrefixFromTheModelIsStripped() {
        XCTAssertEqual(rendered(resolved(.advertisement, "[Sponsor] Squarespace")), "\(sponsorPrefix) Squarespace")
        XCTAssertEqual(rendered(resolved(.advertisement, "sponsor: Squarespace")), "\(sponsorPrefix) Squarespace")
    }

    func testAnUnnamedAdvertisementIsStillCategorised() {
        let result = resolved(.advertisement, "")
        XCTAssertEqual(result.category, .sponsor)
        XCTAssertNil(result.title)
        XCTAssertEqual(rendered(result), sponsorPrefix)
    }

    func testSelfPromotionKeepsItsOwnCategory() {
        let result = resolved(.selfPromotion, "Membership")
        XCTAssertEqual(result.category, .selfpromo)
        XCTAssertEqual(result.title, "Membership")
    }

    func testSomethingThatIsntAPromotionIsMarkedNotTranscribed() {
        let result = resolved(.notPromotional, "Listener questions")
        XCTAssertEqual(result.category, .notTranscribed)
        XCTAssertEqual(result.title, "Listener questions")
        XCTAssertEqual(rendered(result), "Listener questions", "a named topic shows its own name")
    }

    func testAParsedCategoryWinsOverNotPromotional() {
        let result = resolved(.notPromotional, "sponsor: Acme")
        XCTAssertEqual(result.category, .sponsor)
        XCTAssertEqual(result.title, "Acme")
    }

    func testAnUnnamedGapCarriesOnlyItsCategory() {
        let result = resolved(.notPromotional, "")
        XCTAssertEqual(result.category, .notTranscribed)
        XCTAssertNil(result.title, "no title is invented for a span nothing could name")
        XCTAssertEqual(rendered(result), String(localized: "categoryNotTranscribed"))
    }

    func testNotTranscribedIsNeitherExternalNorPrioritised() {
        XCTAssertFalse(ChapterCategory.notTranscribed.isExternal)
        XCTAssertFalse(ChapterCategory.notTranscribed.hasPriority)
        XCTAssertNil(ChapterCategory.notTranscribed.apiName, "SponsorBlock must never be asked for it")
    }

    func testNotTranscribedStaysLastSoStoredValuesKeepMeaning() {
        XCTAssertEqual(ChapterCategory.allCases.last, .notTranscribed)
        XCTAssertEqual(ChapterCategory.sponsor.rawValue, 0)
        XCTAssertEqual(ChapterCategory.generated.rawValue, 9)
    }
}
