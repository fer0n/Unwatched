//
//  SignalInterval.swift
//  Unwatched
//

import Foundation

extension UserDefaults {
    func shouldPerform(_ identifier: String, interval: SignalInterval) -> Bool {
        guard isDue(identifier, interval: interval) else {
            return false
        }
        markPerformed(identifier)
        return true
    }

    /// Pair with `markPerformed` when work should only count as done once it finishes
    func isDue(_ identifier: String, interval: SignalInterval) -> Bool {
        let lastSent = object(forKey: lastSentKey(identifier)) as? Date ?? Date.distantPast
        return Date().timeIntervalSince(lastSent) >= interval.timeInterval
    }

    func markPerformed(_ identifier: String) {
        set(Date(), forKey: lastSentKey(identifier))
    }

    private func lastSentKey(_ identifier: String) -> String {
        "lastSent_\(identifier)"
    }
}

enum SignalInterval {
    case hourly
    case daily
    case weekly
    case fortNightly
    case monthly
    case custom(TimeInterval)

    var timeInterval: TimeInterval {
        switch self {
        case .hourly:
            return 60 * 60
        case .daily:
            return 60 * 60 * 24
        case .weekly:
            return 60 * 60 * 24 * 7
        case .fortNightly:
            return 60 * 60 * 24 * 14
        case .monthly:
            return 60 * 60 * 24 * 30
        case .custom(let interval):
            return interval
        }
    }
}
