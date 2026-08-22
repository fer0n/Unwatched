//
//  LaunchTrace.swift
//  UnwatchedShared
//

import Foundation
import OSLog
import SwiftUI

/// Records when each launch phase happened, measured from **process start** rather than from
/// `main`, so the dynamic linking and runtime setup that runs before any app code is included.
///
/// Only records anything when the app is launched with the `launch-trace` argument, so it costs
/// one boolean check per mark in a normal run. `LaunchTraceReporter` hands the recorded marks to
/// `LaunchTraceTests`, which asserts that work the first frame doesn't need stays off the launch
/// critical path.
public enum LaunchTrace {
    public static let isEnabled = CommandLine.arguments.contains("launch-trace")

    /// Identifier the UI test looks the reporter up by.
    public static let elementId = "launchTrace"

    /// Wall-clock process start, from the kernel's process info. `ProcessInfo` has no equivalent,
    /// and anything measured inside the process necessarily starts too late.
    private static let processStart: Double = {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        guard sysctl(&mib, u_int(mib.count), &info, &size, nil, 0) == 0 else {
            return Date().timeIntervalSince1970
        }
        let start = info.kp_proc.p_starttime
        return Double(start.tv_sec) + Double(start.tv_usec) / 1_000_000
    }()

    /// Mirrors each mark to the console, so a launch can also be read with
    /// `log stream --predicate 'subsystem BEGINSWITH "com.pentlandFirth.Unwatched"'`.
    private static let logger = Logger(subsystem: "com.pentlandFirth.Unwatched", category: "LaunchTrace")

    private static let lock = NSLock()
    private nonisolated(unsafe) static var marks: [(name: String, elapsed: Double)] = []

    /// Milliseconds since process start, for the phase named `name`.
    public static func mark(_ name: String) {
        guard isEnabled else { return }
        let elapsed = (Date().timeIntervalSince1970 - processStart) * 1000
        lock.withLock { marks.append((name, elapsed)) }
        logger.log("LAUNCHTRACE \(name, privacy: .public) \(Int(elapsed.rounded()), privacy: .public)")
    }

    /// `name:milliseconds` pairs, in the order they were recorded.
    public static var summary: String {
        lock.withLock {
            marks.map { "\($0.name):\(Int($0.elapsed.rounded()))" }.joined(separator: ",")
        }
    }

    public enum Phase {
        public static let containerBegin = "container.begin"
        public static let containerEnd = "container.end"
        public static let didFinishLaunchingBegin = "didFinishLaunching.begin"
        public static let didFinishLaunchingEnd = "didFinishLaunching.end"
        /// The scene became active, which happens right after the first frame is on screen.
        public static let sceneActive = "sceneActive"
        public static let webViewWarmupBegin = "webViewWarmup.begin"
        public static let webViewWarmupEnd = "webViewWarmup.end"
    }
}

#if os(iOS) || os(visionOS)
/// Exposes `LaunchTrace.summary` to UI tests as an accessibility value.
///
/// A plain `UIView` rather than a SwiftUI element because it answers every accessibility query
/// with the marks recorded *by then* — a SwiftUI value would be frozen at the render that
/// produced it, which is before the phases the test cares about have happened.
public struct LaunchTraceReporter: UIViewRepresentable {
    public init() { }

    public func makeUIView(context: Context) -> UIView {
        LaunchTraceReporterView()
    }

    public func updateUIView(_ view: UIView, context: Context) { }
}

private final class LaunchTraceReporterView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = true
        accessibilityIdentifier = LaunchTrace.elementId
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var accessibilityValue: String? {
        get { LaunchTrace.summary }
        set { }
    }
}
#endif
