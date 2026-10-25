//
//  Log.swift
//  Unwatched
//

import Foundation
import OSLog
import Synchronization

public struct Log: Sendable {
    public static let general = Log(category: "General")
    public static let player = Log(category: "Player")
    public static let hls = Log(category: "HLS")
    public static let innerTube = Log(category: "InnerTube")
    public static let refresh = Log(category: "Refresh")
    public static let sync = Log(category: "Sync")
    public static let chapters = Log(category: "Chapters")
    public static let podcasts = Log(category: "Podcasts")
    public static let data = Log(category: "Data")
    public static let browser = Log(category: "Browser")

    public static let logFile = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask).first?
        .appendingPathComponent("Unwatched.log")

    private static let fileLogging = Mutex(Const.enableLogging.bool ?? false)
    private static let fileWriter = logFile.map(LogFileWriter.init)

    private let category: String
    private let logger: Logger
    private let osLog: OSLog

    public init(category: String) {
        self.category = category
        logger = Logger(subsystem: appSubsystem, category: category)
        osLog = OSLog(subsystem: appSubsystem, category: category)
    }

    public static var isFileLoggingEnabled: Bool {
        fileLogging.withLock { $0 }
    }

    public static func setIsEnabled(_ enabled: Bool) {
        fileLogging.withLock { $0 = enabled }
    }

    public static func deleteLogFile() {
        fileWriter?.delete()
    }

    public func debug(_ message: @autoclosure () -> String, sensitive: Bool = false) {
        log(message, level: .debug, sensitive: sensitive)
    }

    public func info(_ message: @autoclosure () -> String, sensitive: Bool = false) {
        log(message, level: .info, sensitive: sensitive)
    }

    public func notice(_ message: @autoclosure () -> String, sensitive: Bool = false) {
        log(message, level: .notice, sensitive: sensitive)
    }

    public func warning(_ message: @autoclosure () -> String, sensitive: Bool = false) {
        log(message, level: .warning, sensitive: sensitive)
    }

    public func error(_ message: @autoclosure () -> String, sensitive: Bool = false) {
        log(message, level: .error, sensitive: sensitive)
    }

    public static func debug(_ message: @autoclosure () -> String, sensitive: Bool = false) {
        general.debug(message(), sensitive: sensitive)
    }

    public static func info(_ message: @autoclosure () -> String, sensitive: Bool = false) {
        general.info(message(), sensitive: sensitive)
    }

    public static func notice(_ message: @autoclosure () -> String, sensitive: Bool = false) {
        general.notice(message(), sensitive: sensitive)
    }

    public static func warning(_ message: @autoclosure () -> String, sensitive: Bool = false) {
        general.warning(message(), sensitive: sensitive)
    }

    public static func error(_ message: @autoclosure () -> String, sensitive: Bool = false) {
        general.error(message(), sensitive: sensitive)
    }

    private func log(_ message: () -> String, level: Level, sensitive: Bool) {
        let writeToFile = Self.isFileLoggingEnabled
        guard writeToFile || osLog.isEnabled(type: level.osLogType) else { return }

        let message = message()
        if sensitive {
            logger.log(level: level.osLogType, "\(message, privacy: .private)")
        } else {
            logger.log(level: level.osLogType, "\(message, privacy: .public)")
        }

        guard writeToFile, let fileWriter = Self.fileWriter else { return }
        let timestamp = Date().formatted(date: .numeric, time: .standard)
        fileWriter.append("\(timestamp) [\(level.rawValue)] [\(category)] \(message)\n")
    }

    private enum Level: String {
        case debug = "Debug"
        case info = "Info"
        case notice = "Notice"
        case warning = "Warning"
        case error = "Error"

        var osLogType: OSLogType {
            switch self {
            case .debug: .debug
            case .info: .info
            case .notice, .warning: .default
            case .error: .error
            }
        }
    }
}
