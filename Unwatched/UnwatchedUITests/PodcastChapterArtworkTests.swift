//
//  PodcastChapterArtworkTests.swift
//  Unwatched
//

import XCTest
import UnwatchedShared

/// Chapter artwork: reading it out of an episode file, and putting it back onto the chapters a show lists.
class PodcastChapterArtworkTests: XCTestCase {
    /// Relay FM and others illustrate every chapter: the picture is an `APIC` frame nested inside the chapter's own,
    /// and it has no URL, so it is filed under one of the app's making.
    func testReadsChapterArtworkFromAnID3Tag() async throws {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "id3-chapter-art-\(UUID().uuidString).mp3")
        try Data(ID3Fixture.taggedFileHead(chapterArtwork: ID3Fixture.pngBytes)).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let episodeId = "pod-\(UUID().uuidString.prefix(8))"
        let read = await ID3ChapterReader.chapters(from: url, episodeId: episodeId)
        let chapters = try XCTUnwrap(read)
        let imageUrl = try XCTUnwrap(chapters[1].imageUrl)
        defer { ImageService.deleteImages([imageUrl]) }

        XCTAssertNil(chapters[0].imageUrl, "only the second chapter carries a picture")
        let stored = await ImageService.imageData(for: imageUrl)
        XCTAssertEqual(stored, Data(ID3Fixture.pngBytes))
    }

    /// A UTF-16 description ends in `00 00`, but so does the low byte of its last character followed by the
    /// terminator's first — reading the picture from the wrong one of those leaves a stray zero in front of the
    /// image, which is enough that nothing can decode it. Lage der Nation's episodes are written this way.
    func testReadsChapterArtworkDescribedInUtf16() async throws {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "id3-wide-art-\(UUID().uuidString).mp3")
        let head = ID3Fixture.taggedFileHead(
            chapterArtwork: ID3Fixture.pngBytes,
            wideDescription: true
        )
        try Data(head).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let episodeId = "pod-\(UUID().uuidString.prefix(8))"
        let read = await ID3ChapterReader.chapters(from: url, episodeId: episodeId)
        let chapters = try XCTUnwrap(read)
        let imageUrl = try XCTUnwrap(chapters[1].imageUrl)
        defer { ImageService.deleteImages([imageUrl]) }

        let stored = await ImageService.imageData(for: imageUrl)
        XCTAssertEqual(stored, Data(ID3Fixture.pngBytes))
    }

    /// A show's `podcast:chapters` file lists titles and times while the pictures for those chapters sit in the
    /// episode file itself, so the two have to be put back together.
    func testMergesChapterImagesByStartTime() {
        let listed = [
            SendableChapter(title: "One", startTime: 0),
            SendableChapter(title: "Two", startTime: 103.368),
            SendableChapter(title: "Three", startTime: 243.818)
        ]
        let embedded = [
            SendableChapter(title: "One", startTime: 0),
            // the file's marks are milliseconds, which don't always land on the file's own value exactly
            SendableChapter(title: "Two", startTime: 103.9, imageUrl: URL(string: "unwatched-chapter://ep/103368")),
            SendableChapter(title: "Off", startTime: 300, imageUrl: URL(string: "unwatched-chapter://ep/300000"))
        ]

        let merged = PodcastService.mergingImages(from: embedded, into: listed)

        XCTAssertEqual(merged.map(\.title), ["One", "Two", "Three"])
        XCTAssertNil(merged[0].imageUrl)
        XCTAssertEqual(merged[1].imageUrl?.absoluteString, "unwatched-chapter://ep/103368")
        // 300 is nowhere near a listed chapter, so it stays out
        XCTAssertNil(merged[2].imageUrl)
    }

    /// Whatever the file says about a chapter that already has a picture is not worth overriding.
    func testMergeKeepsExistingChapterImages() {
        let listed = [
            SendableChapter(title: "One", startTime: 10, imageUrl: URL(string: "https://example.com/own.jpg"))
        ]
        let embedded = [
            SendableChapter(title: "One", startTime: 10, imageUrl: URL(string: "unwatched-chapter://ep/10000"))
        ]

        let merged = PodcastService.mergingImages(from: embedded, into: listed)
        XCTAssertEqual(merged[0].imageUrl?.absoluteString, "https://example.com/own.jpg")
    }
}

/// An ID3v2.3 tag head, built the way a podcast host writes one.
enum ID3Fixture {
    /// Enough of a PNG to be told apart from the bytes around it.
    static let pngBytes: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x01, 0x02, 0x03]

    /// An ID3v2.3 head with two chapters, built the way a podcast host writes one.
    /// - Parameter wideDescription: writes the picture's description as UTF-16, the way Auphonic (and so Lage der
    /// Nation) does, rather than as latin-1.
    static func taggedFileHead(
        artworkBytes: Int = 0,
        chapterArtwork: [UInt8]? = nil,
        wideDescription: Bool = false
    ) -> [UInt8] {
        func frame(_ id: String, _ payload: [UInt8]) -> [UInt8] {
            let size = UInt32(payload.count)
            return Array(id.utf8)
                + [UInt8(size >> 24), UInt8((size >> 16) & 0xFF), UInt8((size >> 8) & 0xFF), UInt8(size & 0xFF)]
                + [0, 0]
                + payload
        }
        func milliseconds(_ value: UInt32) -> [UInt8] {
            [UInt8(value >> 24), UInt8((value >> 16) & 0xFF), UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF)]
        }
        func chapter(
            _ id: String,
            start: UInt32,
            end: UInt32,
            title: String,
            url: String? = nil,
            picture: [UInt8]? = nil,
            wideDescription: Bool = false
        ) -> [UInt8] {
            var payload = Array(id.utf8) + [0]
            payload += milliseconds(start) + milliseconds(end)
            payload += milliseconds(0xFFFF_FFFF) + milliseconds(0xFFFF_FFFF)
            payload += frame("TIT2", [0] + Array(title.utf8))
            if let url {
                payload += frame("WXXX", [0] + Array("link".utf8) + [0] + Array(url.utf8))
            }
            if let picture {
                // encoding, MIME type, picture type, description, then the image itself
                let description: [UInt8] = wideDescription
                    // BOM, then each character as a low byte and a high byte, ended by a wide zero
                    ? [0xFF, 0xFE] + Array("cover".utf8).flatMap { [$0, 0] } + [0, 0]
                    : Array("cover".utf8) + [0]
                payload += frame(
                    "APIC",
                    [wideDescription ? 1 : 0] + Array("image/png".utf8) + [0, 3] + description + picture
                )
            }
            return frame("CHAP", payload)
        }

        var body = frame("TIT2", [0] + Array("Episode One".utf8))
        if artworkBytes > 0 {
            body += frame("APIC", [UInt8](repeating: 0x2A, count: artworkBytes))
        }
        body += chapter("ch0", start: 0, end: 90_000, title: "Intro")
        body += chapter(
            "ch1",
            start: 90_000,
            end: 180_000,
            title: "Main topic",
            url: "https://example.com/topic",
            picture: chapterArtwork,
            wideDescription: wideDescription
        )

        let size = UInt32(body.count)
        let synchsafe: [UInt8] = [
            UInt8((size >> 21) & 0x7F), UInt8((size >> 14) & 0x7F),
            UInt8((size >> 7) & 0x7F), UInt8(size & 0x7F)
        ]
        return Array("ID3".utf8) + [3, 0, 0] + synchsafe + body
    }
}
