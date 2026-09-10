//
//  WatchPayload.swift
//  UnwatchedShared
//

import Foundation

/// Anything the phone and the watch send each other: `WCSession` carries `Data`, not values.
public protocol WatchPayload: Codable, Sendable {
    static var payloadKey: String { get }
}

public extension WatchPayload {
    func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }

    static func decoded(_ data: Data) throws -> Self {
        try JSONDecoder().decode(Self.self, from: data)
    }

    static func decoded(from message: [String: Any]) -> Self? {
        guard let data = message[payloadKey] as? Data else { return nil }
        return try? decoded(data)
    }

    func message() throws -> [String: Any] {
        [Self.payloadKey: try encoded()]
    }
}
