//
//  Logger.swift
//  Unwatched
//

import Foundation
import OSLog

extension Logger: @unchecked Sendable {
    /// Logs the view cycles like a view that appeared.
    static let log = Logger(subsystem: "com.pentlandFirth.Unwatched.UnwatchedShared", category: "viewcycle")
}

#if swift(>=6.0)
#warning("Reevaluate whether this decoration is necessary.")
#endif


public class Log {
    private static var isEnabled: Bool = Const.enableLogging.bool ?? false
    
    public static var logFile: URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
               let fileName = "Unwatched.log"
           return documentsDirectory.appendingPathComponent(fileName)
    }
    
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "FileLogger")
    
    public static func info(_ message: String) {
        log(message, level: .info)
    }
    
    public static func error(_ message: String) {
        log(message, level: .error)
    }
    
    public static func warning(_ message: String) {
        log(message, level: .fault)
    }

    public static func setIsEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }
    
    static func log(_ message: String, level: OSLogType = .default) {
        logger.log(level: level, "\(message)")

        guard isEnabled, let logFile else {
            return
        }

        let timestamp = Date().formatted(date: .numeric, time: .standard)
        let logLine = "\(timestamp) [\(level.name)] \(message)\n"
        

        do {
            guard let data = logLine.data(using: String.Encoding.utf8) else { return }
            let fileHandle = try FileHandle(forWritingTo: logFile)
            fileHandle.seekToEndOfFile()
            fileHandle.write(data)
            fileHandle.closeFile()
        } catch {
            // file doesn't exist, create it
            let deviceInfo = Device.versionInfo
            let text = """
                \(deviceInfo)
                
                \(logLine)
                """
            guard let data = text.data(using: .utf8) else { return }
            try? data.write(to: logFile, options: .atomicWrite)
        }
    }


    public static func deleteLogFile() {
        guard let logFile else { return }
        do {
            try FileManager.default.removeItem(at: logFile)
            logger.info("Log file deleted.")
        } catch {
            logger.error("Failed to delete log file: \(error.localizedDescription)")
        }
    }
}

// Helper extension for OSLogType names
extension OSLogType {
    var name: String {
        switch self {
        case .default: return "DEFAULT"
        case .info: return "Info"
        case .debug: return "Debug"
        case .error: return "Error"
        case .fault: return "Fault"
        default: return "Unknown"
        }
    }
}
