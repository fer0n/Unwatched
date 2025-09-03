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
        sendSettings()
        #endif
    }

    static func sendSettings() {
        let signalType = "SettingsSnapshot"
        let shouldSend = UserDefaults.standard.shouldSendThrottledSignal(
            signalType: signalType,
            interval: .fortNightly
        )
        if shouldSend {
            let nonDefault = UserDataService.getNonDefaultSettings(prefixValue: "Unwatched.Setting.")
            log(signalType, parameters: nonDefault)
            signalSubscriptionCount()
        }
    }

    static func signalSubscriptionCount() {
        let task = SubscriptionService.getActiveSubscriptionCount()
        Task {
            let count = await task.value
            let rounded = round(Double(count ?? 0) / 10) * 10
            log("SubscriptionCount", parameters: ["SubscriptionCount.Value": "\(rounded)"])
        }
    }

    static func signalBool(_ signalName: String, value: Bool) {
        #if os(iOS)
        TelemetryDeck.signal("\(signalName).\(value ? "Enabled" : "Disabled")")
        #endif
    }

    static func log(_ signalName: String, parameters: [String: String] = [:]) {
        #if os(iOS)
        if !(Const.analytics.bool ?? true) { return }
        Log.info("Signal: \(signalName)")
        TelemetryDeck.signal(signalName, parameters: parameters)
        #endif
    }
}

extension View {
    func signalToggle(_ name: String, isOn: Bool) -> some View {
        self.onChange(of: isOn) {
            Signal.log("\(name).\(isOn ? "Enabled" : "Disabled")")
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
