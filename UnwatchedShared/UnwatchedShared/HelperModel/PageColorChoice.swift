//
//  PageColorChoice.swift
//  UnwatchedShared
//

import SwiftUI

/// Stored as `Subscription._tint`.
public enum PageColorChoice: Hashable, Sendable {
    case automatic
    case monochrome
    case custom(hex: String)

    private static let monochromeRawValue = "monochrome"

    public init(rawValue: String?) {
        switch rawValue {
        case Self.monochromeRawValue?:
            self = .monochrome
        case let hex? where hex.count == 6 && hex.allSatisfy(\.isHexDigit):
            self = .custom(hex: hex)
        default:
            self = .automatic
        }
    }

    public init(color: Color) {
        self = .custom(hex: color.toHex())
    }

    public var rawValue: String? {
        switch self {
        case .automatic: nil
        case .monochrome: Self.monochromeRawValue
        case .custom(let hex): hex
        }
    }

    public var customColor: Color? {
        if case .custom(let hex) = self {
            return Color(hex: hex)
        }
        return nil
    }
}
