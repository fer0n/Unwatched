//
//  Logger.swift
//  Unwatched
//

import Foundation
import OSLog

extension Logger: @unchecked Sendable {
    /// Using your bundle identifier is a great way to ensure a unique identifier.
    private static var subsystem: String {
        return Bundle.main.bundleIdentifier ?? "default"
    }

    /// Logs the view cycles like a view that appeared.
    static let log = Logger(subsystem: subsystem, category: "viewcycle")
}

#if swift(>=6.0)
#warning("Reevaluate whether this decoration is necessary.")
#endif
