//
//  Event.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared
#if canImport(UIKit)
import UIKit
#endif

struct Signal {
    static var isTestFlight: Bool { BuildInfo.isTestFlight }

    /// Which build produced an event. Rides along on every event so local testing can be
    /// kept out of the live numbers: the dashboard excludes `debug` by default while still
    /// letting it be inspected, which means the analytics path stays exercised in
    /// development instead of only being proven after release.
    static var buildChannel: String { BuildInfo.channel }

    /// e.g. "2.0.1", with the build number appended off release
    static let appVersion: String = BuildInfo.version

    static func setup() {
        #if os(iOS) || os(visionOS)
        AnalyticsSettings.migrateIfNeeded()
        if !AnalyticsSettings.isEnabled { return }
        Task {
            await AnalyticsQueue.shared.flush()
        }
        #endif
    }

    /// Flush the analytics queue when leaving the foreground. Wrapped in a background-task
    /// assertion so the in-flight request isn't killed while the app suspends.
    static func flushOnBackground() {
        #if os(iOS) || os(visionOS)
        if !AnalyticsSettings.isEnabled { return }
        Task { @MainActor in
            let app = UIApplication.shared
            var taskId: UIBackgroundTaskIdentifier = .invalid
            taskId = app.beginBackgroundTask(withName: "AnalyticsFlush") {
                app.endBackgroundTask(taskId)
                taskId = .invalid
            }
            await AnalyticsQueue.shared.flush()
            if taskId != .invalid {
                app.endBackgroundTask(taskId)
            }
        }
        #endif
    }

    static func signalBool(_ signalName: String, value: Bool) {
        log(signalName, parameters: ["value": onOff(value)])
    }

    static func onOff(_ value: Bool) -> String {
        value ? "On" : "Off"
    }

    static func log(
        _ signalName: String,
        parameters: [String: String] = [:],
        throttle: SignalInterval? = nil,
        throttleKey: String? = nil,
        includeUserId: Bool = true
    ) {
        #if os(iOS) || os(visionOS)
        // before the throttle, which marks its window as used
        if !AnalyticsSettings.isEnabled { return }
        if let throttle {
            // `throttleKey` lets callers rate-limit per sub-type (e.g. per gesture) while
            // keeping a single low-cardinality event name. Defaults to the event name.
            // Namespaced in debug because a development build shares UserDefaults with an
            // installed release build: an un-namespaced key would let local testing consume
            // the weekly/fortnightly snapshot window and suppress the real event.
            #if DEBUG
            let throttleId = "debug.\(throttleKey ?? signalName)"
            #else
            let throttleId = throttleKey ?? signalName
            #endif
            if !UserDefaults.standard.shouldPerform(throttleId, interval: throttle) {
                return
            }
        }
        Log.info("Signal: \(signalName)")
        let event = AnalyticsEvent(name: signalName, params: parameters, includeUserId: includeUserId)
        Task {
            await AnalyticsQueue.shared.enqueue(event)
        }
        #endif
    }

    /// Errors are logged unidentified — a crash/error id should never build a per-user
    /// profile, and error moments shouldn't count toward active-user metrics.
    static func error(_ id: String) {
        log("Error", parameters: ["id": id], throttle: .hourly, throttleKey: "Error.\(id)", includeUserId: false)
    }

    /// Bypasses `log`, which the already-disabled setting would block, and drops anything still queued.
    static func handleOptOut() {
        #if os(iOS) || os(visionOS)
        Log.info("Signal: Analytics opt-out")
        let event = AnalyticsEvent(name: "Analytics", params: ["value": "Off"], includeUserId: false)
        Task {
            await AnalyticsQueue.shared.replaceAll(with: event)
        }
        #endif
    }

    static func bucket(_ count: Int) -> String {
        switch count {
        case 0: return "0"
        case 1...4: return "1-4"
        case 5...9: return "5-9"
        case 10...24: return "10-24"
        case 25...49: return "25-49"
        case 50...99: return "50-99"
        case 100...499: return "100-499"
        case 500...999: return "500-999"
        default: return "1000+"
        }
    }

    /// Coarse device family for the per-user snapshot. Low-cardinality, non-identifying.
    static var deviceCategory: String {
        #if os(visionOS)
        return "Vision Pro"
        #elseif os(macOS)
        return "Mac"
        #elseif os(tvOS)
        return "Apple TV"
        #elseif canImport(UIKit)
        switch UIDevice.current.userInterfaceIdiom {
        case .pad: return "iPad"
        case .phone: return "iPhone"
        case .mac: return "Mac"
        case .vision: return "Vision Pro"
        case .tv: return "Apple TV"
        default: return "Unknown"
        }
        #else
        return "Unknown"
        #endif
    }

    /// Raw hardware identifier, e.g. "iPhone17,3". Sent as-is rather than a marketing
    /// name mapped on-device: the identifier→name table lives in the dashboard instead,
    /// so a new device Apple ships shows up correctly without an app update.
    static var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafeBytes(of: &systemInfo.machine) { bytes -> String in
            let data = Data(bytes)
            return String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .controlCharacters)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\0")) ?? "unknown"
        }
        #if targetEnvironment(simulator)
        // On the simulator `machine` is the host Mac's architecture; the simulated
        // device's real identifier is exposed via this env var instead.
        return ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? machine
        #else
        return machine
        #endif
    }

    /// Platform + major.minor OS version, e.g. "iOS 26.5". Patch is dropped on purpose
    /// to keep cardinality low (we don't need 26.5.0 vs 26.5.1).
    static var osVersion: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let name: String
        #if os(visionOS)
        name = "visionOS"
        #elseif os(macOS)
        name = "macOS"
        #elseif os(tvOS)
        name = "tvOS"
        #elseif canImport(UIKit)
        name = UIDevice.current.userInterfaceIdiom == .pad ? "iPadOS" : "iOS"
        #else
        name = "OS"
        #endif
        return "\(name) \(version.majorVersion).\(version.minorVersion)"
    }
}

extension View {
    func signalToggle(_ name: String, isOn: Bool) -> some View {
        self.onChange(of: isOn) {
            #if os(iOS) || os(visionOS)
            Signal.log(name, parameters: ["value": Signal.onOff(isOn)])
            #endif
        }
    }
}

/// Which surface a video-list action was performed from. Set once per screen via
/// `.environment(\.videoListContext, …)` and read by the shared action funnels
/// (tap, swipe, queue button) so analytics can compare behaviour across surfaces
/// (e.g. "what do people do with search results?") without threading a parameter
/// through every view initializer.
enum VideoListContext: String {
    case queue
    case inbox
    case inboxCards
    case search
    case browser
    case subscription
    case detail
    case other
}

private struct VideoListContextKey: EnvironmentKey {
    static let defaultValue: VideoListContext = .other
}

extension EnvironmentValues {
    var videoListContext: VideoListContext {
        get { self[VideoListContextKey.self] }
        set { self[VideoListContextKey.self] = newValue }
    }
}

extension Signal {
    /// Consolidated video-list action event. `action` and `context` are both
    /// low-cardinality, code-defined strings — never free text. See analytics CLAUDE.md.
    /// `via` (optional) records the input mechanism for the action, e.g. `swipe` / `menu` /
    /// `button`, so we can compare e.g. swipe-to-queue vs. the long-press more menu.
    static func videoAction(_ action: String, _ context: VideoListContext, via: String? = nil) {
        var params = ["action": action, "context": context.rawValue]
        if let via {
            params["via"] = via
        }
        log(
            "Video.Action",
            parameters: params,
            throttle: .daily,
            throttleKey: "Video.Action.\(action).\(context.rawValue).\(via ?? "-")"
        )
    }

    /// A repeatable interaction, throttled daily per distinct parameter combination.
    static func interaction(_ name: String, _ variant: String? = nil, parameters: [String: String] = [:]) {
        var params = parameters
        if let variant {
            params["action"] = variant
        }
        let key = ([name] + params.sorted { $0.key < $1.key }.map(\.value)).joined(separator: ".")
        log(name, parameters: params, throttle: .daily, throttleKey: key)
    }

    /// A video started playing from a deliberate user action, tagged with where it was
    /// started from (`source` is a fixed, code-defined string; see call sites). One event
    /// per start — automatic continuous-play advances are intentionally not counted, so this
    /// can be charted as a clean breakdown of how users begin playback.
    static func playbackStarted(_ source: String) {
        log("Player.Start", parameters: ["source": source])
    }

    static func onboardingStep(_ step: String, parameters: [String: String] = [:]) {
        var params = parameters
        params["step"] = step
        log("Onboarding.Step", parameters: params)
    }

    static func generationResult(_ kind: String, _ outcome: String) {
        log("Generation.Result", parameters: ["kind": kind, "outcome": outcome])
    }

    /// A player gesture was performed. Throttled to one event per gesture *type* per day so
    /// individual-gesture adoption stays measurable without flooding on repeated double-tap
    /// seeks or swipe drags. `type` is a fixed, code-defined string (see `GestureType`).
    static func gesture(_ type: String) {
        log("Player.Gesture", parameters: ["type": type], throttle: .daily, throttleKey: "Player.Gesture.\(type)")
    }
}
