//
//  TagEntity.swift
//  Unwatched
//

import AppIntents
import SwiftData
import UnwatchedShared

/// Identified by name, not `PersistentIdentifier`: a saved shortcut stores the identifier, and a
/// name survives the store being rebuilt from a backup.
struct TagEntity: AppEntity {
    let id: String

    @Property(title: "tagName")
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(stringLiteral: name)
    }

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Tag"

    static let defaultQuery = TagEntityQuery()

    init(name: String) {
        self.id = name
        self.name = name
    }

    /// Throws once the tag is gone: a shortcut naming a tag that no longer exists would otherwise
    /// play whichever slice happened to be latched.
    @MainActor
    func selection() throws -> QueueTagSelection {
        guard let tag = TagEntityQuery.tag(named: name) else {
            throw BackgroundPlaybackError.tagNotFound
        }
        return .tag(tag.persistentModelID)
    }
}

struct TagEntityQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [TagEntity.ID]) async throws -> [TagEntity] {
        TagEntityQuery.allTags()
            .filter { identifiers.contains($0.name) }
            .map { TagEntity(name: $0.name) }
    }

    @MainActor
    func suggestedEntities() async throws -> [TagEntity] {
        TagEntityQuery.allTags().map { TagEntity(name: $0.name) }
    }

    @MainActor
    static func allTags() -> [Tag] {
        let fetch = FetchDescriptor<Tag>(sortBy: [SortDescriptor(\Tag.order)])
        return (try? DataProvider.mainContext.fetch(fetch)) ?? []
    }

    @MainActor
    static func tag(named name: String) -> Tag? {
        allTags().first { $0.name == name }
    }
}
