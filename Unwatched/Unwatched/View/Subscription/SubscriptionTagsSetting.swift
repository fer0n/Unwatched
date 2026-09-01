//
//  SubscriptionTagsSetting.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

struct SubscriptionTagsSetting: View {
    @Environment(\.modelContext) var modelContext

    /// Only the `include` tags: adding a channel to one of the others would take it *out* of what
    /// that tag shows, which no menu of tags to assign can say. They are edited from the tag sheet.
    @Query(filter: Tag.includeMode, sort: \Tag.order) private var tags: [Tag]

    @Bindable var subscription: Subscription

    @State private var newTag: TagEdit?

    var body: some View {
        if subscription.subscriptionKey != nil {
            menu
        }
    }

    private var menu: some View {
        Menu {
            ForEach(tags) { tag in
                Button {
                    withAnimation {
                        toggle(tag)
                    }
                } label: {
                    if tag.covers(subscription) {
                        Label(tag.name, systemImage: Const.checkmarkSF)
                    } else {
                        Label(tag.name, systemImage: tag.displaySymbol)
                    }
                }
            }

            Divider()

            Button {
                newTag = .new(covering: subscription)
            } label: {
                Label("newTag", systemImage: "plus")
            }
        } label: {
            let assigned = assignedTags
            CapsuleLabel(text: label(assigned)) {
                Image(systemName: assigned.count == 1 ? assigned[0].displaySymbol : Const.filterTagSF)
            }
        }
        .buttonStyle(CapsuleButtonStyle(primary: false))
        .sheet(item: $newTag) { edit in
            TagEditView(tag: edit.tag, isNew: edit.isNew)
        }
    }

    private var assignedTags: [Tag] {
        tags.filter { $0.covers(subscription) }
    }

    private func label(_ assigned: [Tag]) -> String {
        assigned.isEmpty
            ? String(localized: "tags")
            : assigned.map(\.name).joined(separator: ", ")
    }

    private func toggle(_ tag: Tag) {
        tag.setCovers(subscription, !tag.covers(subscription))
        try? modelContext.save()
    }
}
