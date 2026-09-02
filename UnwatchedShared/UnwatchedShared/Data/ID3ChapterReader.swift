//
//  ID3ChapterReader.swift
//  UnwatchedShared
//

import Foundation
import OSLog

/// Reads the chapter marks a podcast writes into the episode file's ID3 tag.
public enum ID3ChapterReader {
    /// Read in one go up front: podcast tags run to a few kilobytes, so this is nearly always the whole of it, and a
    /// second request only happens for a tag with cover art in it.
    private static let initialRead = 64 * 1024
    /// How much of a tag is worth pulling over the network.
    private static let maximumRemoteTagSize = 4 << 20
    /// A downloaded episode is read off disk, so the only thing the ceiling bounds is the parse.
    private static let maximumLocalTagSize = 32 << 20

    /// - Parameter episodeId: what a chapter's own picture is filed under, see `ChapterImageStore`.
    public static func chapters(from url: URL, episodeId: String? = nil) async -> [SendableChapter]? {
        let maximumTagSize = url.isFileURL ? maximumLocalTagSize : maximumRemoteTagSize
        guard let head = await bytes(from: url, range: 0..<initialRead) else {
            return nil
        }
        if let chapters = parsed(inHead: head, maximumTagSize: maximumTagSize) {
            return await storingImages(chapters, episodeId: episodeId)
        }
        // the tag didn't fit in the first read: ask for exactly as much as it says it needs
        guard let size = tagSize(head, maximum: maximumTagSize), size + 10 > head.count,
              let full = await bytes(from: url, range: 0..<(size + 10)),
              let chapters = parsed(inHead: full, maximumTagSize: maximumTagSize) else {
            return nil
        }
        return await storingImages(chapters, episodeId: episodeId)
    }

    /// The chapters in a file's leading bytes, or nil when there is no complete tag there.
    public static func chapters(inHead head: [UInt8]) -> [SendableChapter]? {
        chapters(inHead: head, maximumTagSize: maximumRemoteTagSize)
    }

    /// A chapter's picture comes out of the tag as bytes, so it travels alongside the chapter until
    /// `ChapterImageStore` gives it a URL the app can show it by.
    private struct ParsedChapter {
        var chapter: SendableChapter
        var picture: Data?
    }

    private static func storingImages(
        _ parsed: [ParsedChapter],
        episodeId: String?
    ) async -> [SendableChapter] {
        guard let episodeId else { return parsed.map(\.chapter) }
        var result = [SendableChapter]()
        for entry in parsed {
            var chapter = entry.chapter
            if let picture = entry.picture {
                chapter.imageUrl = await ChapterImageStore.store(
                    picture, videoId: episodeId, startTime: chapter.startTime
                )
            }
            result.append(chapter)
        }
        return result
    }

    private static func chapters(inHead head: [UInt8], maximumTagSize: Int) -> [SendableChapter]? {
        parsed(inHead: head, maximumTagSize: maximumTagSize)?.map(\.chapter)
    }

    private static func parsed(inHead head: [UInt8], maximumTagSize: Int) -> [ParsedChapter]? {
        guard let size = tagSize(head, maximum: maximumTagSize), head.count >= 10 + size else {
            return nil
        }
        let majorVersion = Int(head[3])
        let flags = head[5]
        // unsynchronisation rewrites frame bytes; rare, and not worth undoing for a nicety
        guard flags & 0x80 == 0 else {
            Log.info("ID3ChapterReader: unsynchronised tag, skipping")
            return nil
        }

        var frames = Array(head[10..<(10 + size)])
        if flags & 0x40 != 0 {
            // extended header: its own size prefix, counted differently per version
            let extendedSize = majorVersion >= 4
                ? synchsafe(frames[0..<4])
                : Int(bigEndian(frames[0..<4])) + 4
            guard extendedSize < frames.count else { return nil }
            frames = Array(frames.dropFirst(extendedSize))
        }

        let chapters = parseFrames(frames, majorVersion: majorVersion)
            .sorted { $0.chapter.startTime < $1.chapter.startTime }
        return chapters.count > 1 ? chapters : nil
    }

    private static func tagSize(_ head: [UInt8], maximum: Int) -> Int? {
        guard head.count >= 10, head.starts(with: Array("ID3".utf8)) else {
            return nil
        }
        let size = synchsafe(head[6..<10])
        return size > 0 && size <= maximum ? size : nil
    }

    // MARK: - Frames

    private static func parseFrames(_ bytes: [UInt8], majorVersion: Int) -> [ParsedChapter] {
        var chapters = [ParsedChapter]()
        forEachFrame(in: bytes, majorVersion: majorVersion) { id, payload in
            guard id == "CHAP" else { return }
            if let chapter = parseChapter(payload, majorVersion: majorVersion) {
                chapters.append(chapter)
            }
        }
        return chapters
    }

    /// `CHAP`: an element id, four 32-bit fields (start/end in milliseconds, start/end byte
    /// offsets), then the frames describing the chapter — a title, sometimes a link, and for shows
    /// that illustrate every chapter a picture of its own.
    private static func parseChapter(_ payload: [UInt8], majorVersion: Int) -> ParsedChapter? {
        guard let idEnd = payload.firstIndex(of: 0) else { return nil }
        let fieldsStart = idEnd + 1
        guard payload.count >= fieldsStart + 16 else { return nil }

        let start = bigEndian(payload[fieldsStart..<(fieldsStart + 4)])
        let end = bigEndian(payload[(fieldsStart + 4)..<(fieldsStart + 8)])

        var title: String?
        var link: URL?
        var picture: Data?
        forEachFrame(in: Array(payload.dropFirst(fieldsStart + 16)), majorVersion: majorVersion) { id, sub in
            switch id {
            case "TIT2":
                title = decodeText(sub)
            case "WXXX":
                link = decodeUserUrl(sub).flatMap(URL.init(string:))
            case "APIC":
                picture = decodePicture(sub)
            default:
                break
            }
        }

        // 0xFFFFFFFF is the "no value" marker for the end time
        let endTime = end == 0xFFFF_FFFF ? nil : Double(end) / 1000
        return ParsedChapter(
            chapter: SendableChapter(
                title: title,
                startTime: Double(start) / 1000,
                endTime: endTime,
                link: link
            ),
            picture: picture
        )
    }

    /// `APIC`: encoding byte, MIME type as plain latin-1, a picture type byte, a description in that encoding, then
    /// the image itself.
    private static func decodePicture(_ payload: [UInt8]) -> Data? {
        guard let encoding = payload.first else { return nil }
        let rest = Array(payload.dropFirst())
        guard let mimeEnd = rest.firstIndex(of: 0), mimeEnd + 1 < rest.count else { return nil }
        let afterType = Array(rest.dropFirst(mimeEnd + 2))
        guard let split = textTerminator(after: encoding, in: afterType) else { return nil }
        let image = afterType.dropFirst(split.upperBound)
        return image.isEmpty ? nil : Data(image)
    }

    private static func forEachFrame(
        in bytes: [UInt8],
        majorVersion: Int,
        body: (String, [UInt8]) -> Void
    ) {
        var index = 0
        while index + 10 <= bytes.count {
            let idBytes = bytes[index..<(index + 4)]
            guard idBytes.allSatisfy({ $0 >= 0x30 && $0 <= 0x5A }) else {
                // padding, or something this doesn't understand: nothing usable follows
                return
            }
            let id = String(decoding: idBytes, as: UTF8.self)
            // 2.4 sizes are synchsafe, 2.3's are plain — reading one as the other truncates frames
            let size = majorVersion >= 4
                ? synchsafe(bytes[(index + 4)..<(index + 8)])
                : Int(bigEndian(bytes[(index + 4)..<(index + 8)]))
            let payloadStart = index + 10
            guard size > 0, payloadStart + size <= bytes.count else { return }

            body(id, Array(bytes[payloadStart..<(payloadStart + size)]))
            index = payloadStart + size
        }
    }

    // MARK: - Values

    /// A text frame: one encoding byte, then the string.
    private static func decodeText(_ payload: [UInt8]) -> String? {
        guard let encoding = payload.first else { return nil }
        let text = decode(Array(payload.dropFirst()), encoding: encoding)
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed?.isEmpty ?? true) ? nil : trimmed
    }

    /// `WXXX`: encoding byte, a description, then the URL as plain latin-1.
    private static func decodeUserUrl(_ payload: [UInt8]) -> String? {
        guard let encoding = payload.first else { return nil }
        let rest = Array(payload.dropFirst())
        guard let split = textTerminator(after: encoding, in: rest) else { return nil }
        let url = Array(rest.dropFirst(split.upperBound))
        return decode(url, encoding: 0)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decode(_ bytes: [UInt8], encoding: UInt8) -> String? {
        let trimmed = Array(bytes.prefix(while: { $0 != 0 || isWideEncoding(encoding) }))
        let decoded: String?
        switch encoding {
        case 0:
            decoded = String(bytes: trimmed, encoding: .isoLatin1)
        case 1:
            decoded = String(bytes: trimmed, encoding: .utf16)
        case 2:
            decoded = String(bytes: trimmed, encoding: .utf16BigEndian)
        default:
            decoded = String(bytes: trimmed, encoding: .utf8)
        }
        return decoded?.replacing("\0", with: "")
    }

    private static func isWideEncoding(_ encoding: UInt8) -> Bool {
        encoding == 1 || encoding == 2
    }

    /// Where the text written in `encoding` ends.
    private static func textTerminator(after encoding: UInt8, in bytes: [UInt8]) -> Range<Int>? {
        let wide = isWideEncoding(encoding)
        return firstRange(of: wide ? [0, 0] : [0], in: bytes, step: wide ? 2 : 1)
    }

    /// `step` keeps a UTF-16 terminator on a character boundary: byte-by-byte, the zeros that fill UTF-16 text
    /// match one byte early and take a zero with them, enough to make the picture that follows undecodable.
    private static func firstRange(of pattern: [UInt8], in bytes: [UInt8], step: Int = 1) -> Range<Int>? {
        guard !pattern.isEmpty, bytes.count >= pattern.count else { return nil }
        for start in Swift.stride(from: 0, through: bytes.count - pattern.count, by: step)
        where Array(bytes[start..<(start + pattern.count)]) == pattern {
            return start..<(start + pattern.count)
        }
        return nil
    }

    private static func synchsafe(_ bytes: ArraySlice<UInt8>) -> Int {
        bytes.reduce(0) { ($0 << 7) | Int($1 & 0x7F) }
    }

    private static func bigEndian(_ bytes: ArraySlice<UInt8>) -> UInt32 {
        bytes.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
    }

    // MARK: - Fetching

    /// A downloaded episode is read off disk: a `Range` header means nothing to a `file://` URL, so URLSession would
    /// hand back the entire episode to get at its first few kilobytes.
    private static func fileBytes(at url: URL, range: Range<Int>) -> [UInt8]? {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return nil
        }
        defer { try? handle.close() }
        do {
            try handle.seek(toOffset: UInt64(range.lowerBound))
            guard let data = try handle.read(upToCount: range.count) else {
                return nil
            }
            return Array(data)
        } catch {
            Log.info("ID3ChapterReader: \(error.localizedDescription)")
            return nil
        }
    }

    private static func bytes(from url: URL, range: Range<Int>) async -> [UInt8]? {
        if url.isFileURL {
            return fileBytes(at: url, range: range)
        }
        var request = URLRequest(url: url)
        request.setValue("bytes=\(range.lowerBound)-\(range.upperBound - 1)", forHTTPHeaderField: "Range")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard response.isSuccessfulHttp else { return nil }
            // a server that ignores the range hands back the whole episode; take the head of it
            return Array(data.prefix(range.count))
        } catch {
            Log.info("ID3ChapterReader: \(error.localizedDescription)")
            return nil
        }
    }
}
