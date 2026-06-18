import Foundation

// MARK: - HLS Audio Language Parser

/// Extracts a quoted attribute value from an HLS tag line.
/// E.g. `extractQuotedHLSAttribute("LANGUAGE", from: "#EXT-X-MEDIA:LANGUAGE=\"en\"")` → `"en"`.
func extractQuotedHLSAttribute(_ name: String, from line: String) -> String? {
    let prefix = "\(name)=\""
    guard let start = line.range(of: prefix) else { return nil }
    let afterQuote = line[start.upperBound...]
    guard let end = afterQuote.firstIndex(of: "\"") else { return nil }
    return String(afterQuote[afterQuote.startIndex..<end])
}

/// Parses dubbed-audio language tracks from a YouTube HLS master manifest.
/// YouTube encodes dubbed languages in `#EXT-X-STREAM-INF` lines via a
/// non-standard `YT-EXT-AUDIO-CONTENT-ID` attribute, rather than the standard
/// `#EXT-X-MEDIA TYPE=AUDIO` approach. This function extracts one `AudioTrack`
/// per unique content ID and inserts a synthetic "Original" entry when the
/// original-audio variants carry no content ID.
///
/// Returns an array sorted: original first, then remaining tracks alphabetically.
func parseHLSAudioLanguages(from manifest: String) -> [AudioTrack] {
    let lines = manifest.components(separatedBy: "\n")
    var seenContentIDs = Set<String>()
    var tracks: [AudioTrack] = []

    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("#EXT-X-STREAM-INF:"),
              trimmed.contains("YT-EXT-AUDIO-CONTENT-ID=") else { continue }

        guard let contentID = extractQuotedHLSAttribute("YT-EXT-AUDIO-CONTENT-ID", from: trimmed),
              !contentID.isEmpty, !seenContentIDs.contains(contentID) else { continue }
        seenContentIDs.insert(contentID)

        // Content ID format: "xx-XX.N" or "xx.N" → language code is everything before last "."
        let langCode: String
        if let dotIdx = contentID.lastIndex(of: ".") {
            langCode = String(contentID[contentID.startIndex..<dotIdx])
        } else {
            langCode = contentID
        }

        // Decode YT-EXT-XTAGS (base64 protobuf) to check for acont=original vs dubbed-auto.
        let isOriginal: Bool
        if let xtags = extractQuotedHLSAttribute("YT-EXT-XTAGS", from: trimmed),
           let padded = { () -> Data? in
               let s = xtags + String(repeating: "=", count: (4 - xtags.count % 4) % 4)
               return Data(base64Encoded: s)
           }(),
           let decoded = String(data: padded, encoding: .utf8)
                       ?? String(data: padded, encoding: .isoLatin1) {
            isOriginal = decoded.contains("original") && !decoded.contains("dubbed")
        } else {
            isOriginal = false
        }

        let name = Locale.current.localizedString(forLanguageCode: langCode) ?? langCode
        tracks.append(AudioTrack(id: contentID, name: name, languageCode: langCode,
                                 isOriginal: isOriginal, contentID: contentID))
    }

    // If dubbed tracks were found but none is marked isOriginal, the original-audio
    // variants carry no YT-EXT-AUDIO-CONTENT-ID — add a synthetic "Original" entry.
    // contentID=nil signals the proxy to keep variants with no CONTENT-ID attribute.
    if !tracks.isEmpty && !tracks.contains(where: \.isOriginal) {
        let synthetic = AudioTrack(id: "yt-original-audio", name: "Original",
                                   languageCode: "original", isOriginal: true,
                                   contentID: nil)
        tracks.insert(synthetic, at: 0)
    }

    return tracks.sorted { a, b in
        if a.isOriginal != b.isOriginal { return a.isOriginal }
        return a.name.localizedCompare(b.name) == .orderedAscending
    }
}
