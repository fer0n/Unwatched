//
//  Event.swift
//  Unwatched
//

import TelemetryDeck
import SwiftUI
import SwiftData
import UnwatchedShared

struct Signal {
    static func setup() {
        #if os(iOS)
        if !(Const.analytics.bool ?? true) { return }
        let config = TelemetryDeck.Config(appID: Credentials.telemetry)
        config.defaultSignalPrefix = "Unwatched."
        config.defaultParameterPrefix = "Unwatched."
        TelemetryDeck.initialize(config: config)
        #endif
    }

    static func signalBool(_ signalName: String, value: Bool) {
        #if os(iOS)
        TelemetryDeck.signal(signalName, parameters: ["value": value ? "On" : "Off"])
        #endif
    }

    static func log(_ signalName: String, parameters: [String: String] = [:], throttle: SignalInterval? = nil) {
        #if os(iOS)
        if let throttle {
            if !UserDefaults.standard.shouldSendThrottledSignal(signalType: signalName, interval: throttle) {
                return
            }
        }
        if !(Const.analytics.bool ?? true) { return }
        Log.info("Signal: \(signalName)")
        TelemetryDeck.signal(signalName, parameters: parameters)
        #endif
    }

    static func error(_ id: String) {
        if !(Const.analytics.bool ?? true) { return }
        TelemetryDeck.errorOccurred(id: id)
    }
}

extension View {
    func signalToggle(_ name: String, isOn: Bool) -> some View {
        self.onChange(of: isOn) {
            Signal.log(name, parameters: ["value": isOn ? "On" : "Off"])
        }
    }
}

extension UserDefaults {
    func shouldSendThrottledSignal(signalType: String, interval: SignalInterval) -> Bool {
        let key = "lastSent_\(signalType)"
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
