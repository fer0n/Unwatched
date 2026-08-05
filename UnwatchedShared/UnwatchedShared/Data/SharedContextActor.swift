//
//  SharedContextActor.swift
//  UnwatchedShared
//

import SwiftData

/// A data actor that writes through the app's one background context instead of one of its own.
///
/// Replaces `@ModelActor`, whose generated init always creates a fresh context. Sharing a serial
/// executor makes conformers mutually exclusive, so one can't delete a row another is holding —
/// reading a property on such a model traps (`_InvalidFutureBackingData.getValue`).
///
/// Serialisation ends at suspension points, so a mutating job has to stay synchronous from fetch
/// to save; hoist network work out and pick models back up with `resolvedModel(withID:)`.
/// Conformers hold no context of their own, so a per-call instance is cheap.
public protocol SharedContextActor: ModelActor {}

public extension SharedContextActor {
    nonisolated var modelContainer: ModelContainer { DataProvider.shared.container }
    nonisolated var modelExecutor: any ModelExecutor { DataProvider.writeExecutor }
}
