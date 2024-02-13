//
//  Task.swift
//  Unwatched
//

import Foundation

extension Task where Success == Never, Failure == Never {
    static func sleep(s seconds: TimeInterval) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
