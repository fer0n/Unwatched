//
//  LogManager.swift
//  Unwatched
//

import Foundation
import OSLog

@Observable class LogManager {
    private(set) var entries: [String] = []

    func export() {
        do {
            let store = try OSLogStore(scope: .currentProcessIdentifier)
            let date = Date.now.addingTimeInterval(-24 * 3600)
            let position = store.position(date: date)

            entries = try store
                .getEntries(at: position)
                .compactMap { $0 as? OSLogEntryLog }
                .filter { $0.subsystem == Bundle.main.bundleIdentifier! }
                .map { "[\($0.date.formatted())] [\($0.category)] \($0.composedMessage)" }

        } catch {
            Logger.log.warning("\(error.localizedDescription, privacy: .public)")
        }
    }
}
