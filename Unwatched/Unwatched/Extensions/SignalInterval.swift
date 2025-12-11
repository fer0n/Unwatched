//
//  SignalInterval.swift
//  Unwatched
//

import Foundation

extension UserDefaults {
    func shouldPerform(_ identifier: String, interval: SignalInterval) -> Bool {
        let key = "lastSent_\(identifier)"
        let lastSent = object(forKey: key) as? Date ?? Date.distantPast
        let shouldSend = Date().timeIntervalSince(lastSent) >= interval.timeInterval

        if shouldSend {
            set(Date(), forKey: key)
        }

        return shouldSend
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
