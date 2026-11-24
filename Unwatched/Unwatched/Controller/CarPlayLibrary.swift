//
//  CarPlayLibrary.swift
//  Unwatched
//

#if os(iOS)
import CarPlay
import SwiftData
import UnwatchedShared

@MainActor
final class CarPlayLibrary {
    private struct Row: Equatable {
        let id: PersistentIdentifier
        let title: String
        let thumbnail: URL?
    }

    let template: CPListTemplate
    private unowned let scene: CarPlaySceneDelegate
    private var rows: [Row]?
    private var pushed: CarPlayQueueList?

    init(scene: CarPlaySceneDelegate) {
        self.scene = scene
        let title = String(localized: "library")
        template = CPListTemplate(title: title, sections: [])
        template.tabTitle = title
        template.tabImage = UIImage(systemName: "books.vertical")
        template.emptyViewTitleVariants = [String(localized: "noSubscriptions")]
    }

    func cancel() {
        let pushed = pushed
        self.pushed = nil
        pushed?.cancel()
    }

    func reload() {
        let fetch = FetchDescriptor<Subscription>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: SubscriptionSorting.title.sortDescriptors
        )
        let subscriptions = (try? DataProvider.mainContext.fetch(fetch)) ?? []
        let rows = subscriptions.map { Row(id: $0.persistentModelID, title: $0.displayTitle, thumbnail: $0.thumbnailUrl) }
        if rows != self.rows {
            self.rows = rows
            let items = subscriptions.prefix(CPListTemplate.maximumItemCount).map(item)
            template.updateSections([CPListSection(items: Array(items))])
        }
        if let pushed, case .subscription(let id) = pushed.content, !rows.contains(where: { $0.id == id }) {
            cancel()
            scene.pop(pushed.template)
        }
        pushed?.reload([])
    }

    private func item(_ subscription: Subscription) -> CPListItem {
        let artwork = scene.artwork
        let url = subscription.thumbnailUrl
        let item = CPListItem(
            text: subscription.displayTitle,
            detailText: nil,
            image: url.flatMap(artwork.cached),
            accessoryImage: nil,
            accessoryType: .disclosureIndicator
        )
        item.handler = { [weak self, id = subscription.persistentModelID, title = subscription.displayTitle] _, completion in
            MainActor.assumeIsolated {
                guard let self else {
                    return completion()
                }
                self.show(id, title: title, completion: completion)
            }
        }
        artwork.attach(url, to: item)
        return item
    }

    private func show(_ id: PersistentIdentifier, title: String, completion: @escaping () -> Void) {
        Log.info("carPlay: showing subscription")
        let list = CarPlayQueueList(.subscription(id), title: title, scene: scene)
        let previous = pushed
        pushed = list
        previous?.cancel()
        list.onFirstRows = { [weak self, weak list] in
            completion()
            if let self, let list, self.pushed === list {
                self.scene.push(list.template)
            }
        }
        list.reload([])
    }
}
#endif
