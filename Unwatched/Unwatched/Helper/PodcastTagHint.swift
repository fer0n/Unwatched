//
//  PodcastTagHint.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

@MainActor
@Observable
final class PodcastTagHint {
    static let shared = PodcastTagHint()

    private(set) var isShown = UserDefaults.standard.bool(forKey: Const.podcastTagHint) {
        didSet { UserDefaults.standard.set(isShown, forKey: Const.podcastTagHint) }
    }

    func show() {
        isShown = true
    }

    func dismiss() {
        isShown = false
    }

    func createTag(in modelContext: ModelContext) {
        let tags = (try? modelContext.fetch(FetchDescriptor<Tag>())) ?? []
        modelContext.insert(Tag.podcastsTag(order: Tag.nextOrder(after: tags)))
        try? modelContext.save()
        dismiss()
    }
}
