//
//  UploadRate+Description.swift
//  Unwatched
//

import Foundation
import UnwatchedShared

extension UploadRate {
    var localizedDescription: String? {
        let parts = [
            videosPerWeek.map { Self.videosText(WeeklyAmount($0)) },
            shortsPerWeek.map { Self.shortsText(WeeklyAmount($0)) }
        ].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var withoutShorts: UploadRate {
        var rate = self
        rate.shortsPerWeek = nil
        return rate
    }

    private static func videosText(_ amount: WeeklyAmount) -> String {
        switch amount {
        case .whole(let count): String(localized: "uploadRateVideosWeek\(count)")
        case .fraction(let amount): String(localized: "uploadRateVideosWeekFraction\(amount)")
        case .belowMinimum: String(localized: "uploadRateVideosBelow\(WeeklyAmount.minimum)")
        }
    }

    private static func shortsText(_ amount: WeeklyAmount) -> String {
        switch amount {
        case .whole(let count): String(localized: "uploadRateShortsWeek\(count)")
        case .fraction(let amount): String(localized: "uploadRateShortsWeekFraction\(amount)")
        case .belowMinimum: String(localized: "uploadRateShortsBelow\(WeeklyAmount.minimum)")
        }
    }
}

private enum WeeklyAmount {
    case whole(Int)
    case fraction(String)
    case belowMinimum

    static let minimum = format(0.01, digits: 2)

    init(_ perWeek: Double) {
        if perWeek >= 0.95 {
            self = .whole(max(1, Int(perWeek.rounded())))
        } else if perWeek >= 0.05 {
            self = .fraction(Self.format(perWeek, digits: 1))
        } else if perWeek >= 0.005 {
            self = .fraction(Self.format(perWeek, digits: 2))
        } else {
            self = .belowMinimum
        }
    }

    private static func format(_ value: Double, digits: Int) -> String {
        value.formatted(.number.precision(.fractionLength(digits)))
    }
}
