//
//  QueueTagSelection.swift
//  UnwatchedShared
//

import Foundation
import SwiftData

/// Which slice of the queue is in view: the whole thing, or one tag.
///
/// `Codable` because both the queue screen and the player latch a selection and persist it.
public enum QueueTagSelection: Codable, Hashable, Sendable {
    case all
    case tag(PersistentIdentifier)

    public var tagId: PersistentIdentifier? {
        if case .tag(let id) = self {
            return id
        }
        return nil
    }

    public init(tagId: PersistentIdentifier?) {
        self = tagId.map { .tag($0) } ?? .all
    }

    public func tag(in tags: [Tag]) -> Tag? {
        guard let tagId else { return nil }
        return tags.first { $0.persistentModelID == tagId }
    }
}
