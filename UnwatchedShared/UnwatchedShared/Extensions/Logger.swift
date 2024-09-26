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
