import Foundation

// Partial mirror of upstream `HLSManifestParser.swift`: only the master-manifest filter, which
// the tvOS player needs to keep AVPlayer on the VISIONOS client's H.264 ladder. The parsers above
// it upstream aren't used here.

/// Produces an AVFoundation-safe HLS master while preserving separate audio renditions.
/// YouTube's VisionOS master mixes H.264 and VP9 variants; tvOS may select an unsupported
/// VP9 entry even when resolution hints are set. Filtering the master (rather than loading
/// a video-only variant) keeps `EXT-X-MEDIA` audio groups and removes incompatible video.
public func filterHLSMasterManifest(
    _ manifest: String,
    maximumHeight: Int,
    requiredVideoCodec: String
) -> String {
    let lines = manifest.components(separatedBy: .newlines)
    var output: [String] = []
    var shouldDropNextURI = false

    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if shouldDropNextURI {
            if trimmed.isEmpty { continue }
            if trimmed.hasPrefix("#EXT-X-STREAM-INF:") {
                shouldDropNextURI = false
            } else if trimmed.hasPrefix("#") {
                output.append(line)
                continue
            } else {
                shouldDropNextURI = false
                continue
            }
        }

        if trimmed.hasPrefix("#EXT-X-STREAM-INF:") {
            let height: Int? =
                trimmed
                .range(of: #"RESOLUTION=\d+x(\d+)"#, options: .regularExpression)
                .map { String(trimmed[$0]) }
                .flatMap { $0.components(separatedBy: "x").last }
                .flatMap(Int.init)
            let codecMatches = trimmed.localizedCaseInsensitiveContains(requiredVideoCodec)
            guard codecMatches, let height, height <= maximumHeight else {
                shouldDropNextURI = true
                continue
            }
            output.append(line)
            continue
        }

        if trimmed.hasPrefix("#EXT-X-MEDIA:"),
            trimmed.localizedCaseInsensitiveContains("TYPE=AUDIO"),
            hlsMediaLineIsOriginalAudio(trimmed)
        {
            if trimmed.contains("DEFAULT=NO") {
                output.append(line.replacingOccurrences(of: "DEFAULT=NO", with: "DEFAULT=YES"))
            } else if !trimmed.contains("DEFAULT=") {
                output.append(line + ",DEFAULT=YES")
            } else {
                output.append(line)
            }
            continue
        }

        output.append(line)
    }

    return output.joined(separator: "\n")
}

private func hlsMediaLineIsOriginalAudio(_ line: String) -> Bool {
    if line.localizedCaseInsensitiveContains("original")
        && !line.localizedCaseInsensitiveContains("dubbed")
    {
        return true
    }
    guard let encoded = extractQuotedHLSAttribute("YT-EXT-XTAGS", from: line) else {
        return false
    }
    let padded = encoded + String(repeating: "=", count: (4 - encoded.count % 4) % 4)
    guard let data = Data(base64Encoded: padded) else { return false }
    return data.range(of: Data("original".utf8)) != nil
        && data.range(of: Data("dubbed".utf8)) == nil
}

private func extractQuotedHLSAttribute(_ name: String, from line: String) -> String? {
    let prefix = "\(name)=\""
    guard let start = line.range(of: prefix) else { return nil }
    let afterQuote = line[start.upperBound...]
    guard let end = afterQuote.firstIndex(of: "\"") else { return nil }
    return String(afterQuote[afterQuote.startIndex..<end])
}
