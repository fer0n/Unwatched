import Foundation

// MARK: - SearchFilter
//
// Ported from SmartTubeIOSCore. Mirrors Android SearchPresenter's filter options:
//   uploadDate | duration | type | sorting
//
// The `params` field sent to InnerTube search is a base64-encoded protobuf
// (manually encoded — no proto dependency required).
//
// Outer message:
//   field 1 (sort):   varint — SortOrder raw value
//   field 2 (filter): LEN    — nested Filter message
//
// Inner Filter message:
//   field 1 (uploadDate): varint — UploadDate raw value (0 = omit)
//   field 2 (type):       varint — VideoType raw value  (0 = omit)
//   field 3 (duration):   varint — Duration raw value   (0 = omit)

struct SearchFilter: Sendable, Equatable {

    // MARK: - Nested enums (mirror Android Constants)

    enum SortOrder: Int, CaseIterable, Sendable {
        case relevance  = 0   // default — no param emitted
        case rating     = 1
        case uploadDate = 2
        case viewCount  = 3

        var label: String {
            switch self {
            case .relevance:  return String(localized: "searchSortRelevance")
            case .rating:     return String(localized: "searchSortRating")
            case .uploadDate: return String(localized: "searchSortUploadDate")
            case .viewCount:  return String(localized: "searchSortViewCount")
            }
        }
    }

    enum UploadDate: Int, CaseIterable, Sendable {
        case anytime   = 0   // default — no param emitted
        case lastHour  = 1
        case today     = 2
        case thisWeek  = 3
        case thisMonth = 4
        case thisYear  = 5

        var label: String {
            switch self {
            case .anytime:   return String(localized: "searchDateAnytime")
            case .lastHour:  return String(localized: "searchDateLastHour")
            case .today:     return String(localized: "searchDateToday")
            case .thisWeek:  return String(localized: "searchDateThisWeek")
            case .thisMonth: return String(localized: "searchDateThisMonth")
            case .thisYear:  return String(localized: "searchDateThisYear")
            }
        }
    }

    enum VideoType: Int, CaseIterable, Sendable {
        case any      = 0   // default — no param emitted
        case video    = 1
        case channel  = 2
        case playlist = 3
        case movie    = 4
    }

    enum Duration: Int, CaseIterable, Sendable {
        case any    = 0   // default — no param emitted
        case short  = 1   // < 4 min
        case medium = 2   // 4 – 20 min
        case long   = 3   // > 20 min

        var label: String {
            switch self {
            case .any:    return String(localized: "searchDurationAny")
            case .short:  return String(localized: "searchDurationShort")
            case .medium: return String(localized: "searchDurationMedium")
            case .long:   return String(localized: "searchDurationLong")
            }
        }
    }

    // MARK: - Properties

    var sortOrder: SortOrder   = .relevance
    var uploadDate: UploadDate = .anytime
    /// Defaults to `.video` so search results render as a clean video list
    /// (channels and playlists are filtered out by YouTube server-side).
    var type: VideoType        = .video
    var duration: Duration     = .any

    static let `default` = SearchFilter()

    var isDefault: Bool { self == .default }

    // MARK: - Params encoding
    //
    // Produces the base64-encoded protobuf string consumed by InnerTube's
    // `params` search field. Returns nil only when nothing needs encoding.

    func encodedParams() -> String? {
        var outer = Data()

        // field 1 — sort order (varint), only when non-default
        if sortOrder != .relevance {
            outer.appendVarintField(fieldNumber: 1, value: sortOrder.rawValue)
        }

        // field 2 — inner filter message (length-delimited)
        var inner = Data()
        if uploadDate != .anytime {
            inner.appendVarintField(fieldNumber: 1, value: uploadDate.rawValue)
        }
        if type != .any {
            inner.appendVarintField(fieldNumber: 2, value: type.rawValue)
        }
        if duration != .any {
            inner.appendVarintField(fieldNumber: 3, value: duration.rawValue)
        }

        if !inner.isEmpty {
            outer.appendLenField(fieldNumber: 2, value: inner)
        }

        guard !outer.isEmpty else { return nil }
        return outer.base64EncodedString()
    }
}

// MARK: - Protobuf encoding helpers (minimal, private to this file)

private extension Data {
    /// Encode a varint tag + varint value: `(fieldNumber << 3) | 0`, then the value.
    mutating func appendVarintField(fieldNumber: Int, value: Int) {
        appendVarint(UInt64((fieldNumber << 3) | 0))  // wire type 0 = varint
        appendVarint(UInt64(value))
    }

    /// Encode a length-delimited tag + embedded bytes: `(fieldNumber << 3) | 2`, length, bytes.
    mutating func appendLenField(fieldNumber: Int, value: Data) {
        appendVarint(UInt64((fieldNumber << 3) | 2))  // wire type 2 = length-delimited
        appendVarint(UInt64(value.count))
        append(value)
    }

    /// Append a base-128 (LEB128) varint.
    mutating func appendVarint(_ value: UInt64) {
        var v = value
        repeat {
            var byte = UInt8(v & 0x7F)
            v >>= 7
            if v != 0 { byte |= 0x80 }
            append(byte)
        } while v != 0
    }
}
