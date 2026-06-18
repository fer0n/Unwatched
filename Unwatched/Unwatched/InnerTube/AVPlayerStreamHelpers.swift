#if !os(macOS)
import UnwatchedShared

enum StreamQualityHelper {
    static let bitRateCaps: [Int: Double] = [
        2160: 45_000_000,
        1440: 20_000_000,
        1080: 15_000_000,
         720:  8_000_000,
         480:  4_000_000,
    ]

    static func peakBitRate(for height: Int) -> Double {
        if let exact = bitRateCaps[height] { return exact }
        let lower = bitRateCaps.keys.sorted().last(where: { $0 <= height }) ?? 480
        return bitRateCaps[lower] ?? 4_000_000
    }

    static func videoQualities(from info: PlayerInfo, muxedOnly: Bool = false) -> [(height: Int, label: String)] {
        var best: [Int: Int] = [:]
        for fmt in info.formats where fmt.height > 0 && fmt.mimeType.hasPrefix("video/") && !fmt.mimeType.contains("vp09") {
            if muxedOnly && !fmt.mimeType.contains(", ") { continue }
            best[fmt.height] = max(best[fmt.height] ?? 0, fmt.fps)
        }
        let sorted = best.sorted { $0.key > $1.key }
        guard !sorted.isEmpty else { return [] }
        let options = sorted.map { height, fps -> (height: Int, label: String) in
            let label = fps > 30 ? "\(height)p\(fps)" : "\(height)p"
            return (height: height, label: label)
        }
        return [(height: 0, label: String(localized: "qualityAuto"))] + options
    }

    static func qualitiesFromHLSManifest(_ m3u8: String) -> [(height: Int, label: String)] {
        var heights = Set<Int>()
        for line in m3u8.components(separatedBy: "\n") {
            guard line.hasPrefix("#EXT-X-STREAM-INF:") else { continue }
            if let resRange = line.range(of: "RESOLUTION="),
               let xIdx = line[resRange.upperBound...].firstIndex(of: "x") {
                let afterX = line.index(after: xIdx)
                let heightStr = String(line[afterX...].prefix(while: { $0.isNumber }))
                if let h = Int(heightStr), h > 0 { heights.insert(h) }
            }
        }
        guard !heights.isEmpty else { return [] }
        let options = heights.sorted(by: >).map { h in (height: h, label: "\(h)p") }
        return [(height: 0, label: String(localized: "qualityAuto"))] + options
    }
}
#endif
