//
//  TagEditView.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

/// Its own id, not the tag's: inserting a new tag swaps its id and reads as a different sheet.
struct TagEdit: Identifiable {
    let id = UUID()
    let tag: Tag
    let isNew: Bool

    /// Not set on the tag: writing a relationship on an uninserted model inserts it.
    var covering: Subscription?

    static func existing(_ tag: Tag) -> TagEdit {
        TagEdit(tag: tag, isNew: false)
    }

    /// Uninserted, so dismissing the sheet discards it; only confirming inserts it.
    static func new(covering subscription: Subscription? = nil) -> TagEdit {
        TagEdit(tag: Tag(name: ""), isNew: true, covering: subscription)
    }
}

/// A new tag comes in uninserted, so dismissing discards it; only `create()` inserts it.
struct TagEditView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss

    @Bindable var tag: Tag
    var isNew = false

    @State private var subscriptions = [Subscription]()
    @State private var otherTagsBySubscription = [PersistentIdentifier: [TagBadge]]()
    @State private var navigationName: String
    @State private var otherNames = Set<String>()

    /// A new tag's channels, until `create()` inserts the tag and can safely link them.
    @State private var pendingSubscriptionIds = Set<PersistentIdentifier>()

    @FocusState private var nameFocused: Bool

    init(tag: Tag, isNew: Bool = false, covering: Subscription? = nil) {
        self.tag = tag
        self.isNew = isNew
        _navigationName = State(initialValue: tag.name)
        _pendingSubscriptionIds = State(initialValue: covering.map { [$0.persistentModelID] } ?? [])
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MyBackgroundColor()

                List {
                    MySection("tagName", footer: nameIsTaken ? "tagNameTakenHelper" : nil) {
                        TextField("tagName", text: $tag.name)
                            .focused($nameFocused)
                            .onSubmit { save() }

                        NavigationLink {
                            TagSymbolPicker(symbol: $tag.symbol, defaultSymbol: tag.mode.defaultSymbol)
                        } label: {
                            HStack {
                                Text("symbol")
                                    .foregroundStyle(Color.neutralAccentColor)
                                Spacer()
                                Image(systemName: tag.displaySymbol)
                            }
                        }
                    }

                    MySection(footer: tag.mode.helper) {
                        Picker(selection: $tag.mode.animation()) {
                            ForEach(TagMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        } label: {
                            Text("tagMode")
                        }
                        .onChange(of: tag.mode) {
                            if !isNew {
                                save()
                            }
                        }
                    }

                    MySection(footer: "quickSwitchHelper") {
                        Toggle(isOn: $tag.quickSwitch) {
                            Text("quickSwitch")
                        }
                    }

                    // an `exclude` tag's videos are also every other tag's, so none of them could follow it alone
                    if tag.mode != .exclude {
                        MySection(footer: "continuousPlayTagHelper") {
                            Picker(selection: $tag.continuousPlay) {
                                Text("useDefault").tag(Bool?.none)
                                Text("on").tag(Bool?.some(true))
                                Text("off").tag(Bool?.some(false))
                            } label: {
                                Text("continuousPlay")
                            }
                        }

                        #if os(iOS)
                        MySection(footer: "suggestVideosTagHelper") {
                            Picker(selection: $tag.suggestVideos) {
                                Text("useDefault").tag(Bool?.none)
                                Text("on").tag(Bool?.some(true))
                                Text("off").tag(Bool?.some(false))
                            } label: {
                                Text("suggestVideos")
                            }
                        }
                        #endif
                    }

                    // an untagged tag is defined by the other tags, so it has nothing to pick
                    if tag.mode != .untagged {
                        let taggedVideos = tag.videos ?? []
                        if !taggedVideos.isEmpty {
                            TaggedVideosSection(
                                title: tag.mode == .exclude ? "excludedVideos" : "videos",
                                tag: tag,
                                videos: taggedVideos
                            )
                        }

                        ChannelsSection(
                            title: tag.mode == .exclude ? "excludedChannels" : "channels",
                            subscriptions: subscriptions,
                            otherTagsBySubscription: otherTagsBySubscription,
                            isCovered: isCovered,
                            toggle: toggle
                        )
                    }

                    if !isNew {
                        MySection {
                            Button(role: .destructive) {
                                delete()
                            } label: {
                                Text("deleteTag")
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .myTint()
            .myNavigationTitle(isNew ? "newTag" : .verbatim(navigationName))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        if isNew {
                            create()
                        } else {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: Const.checkmarkSF)
                    }
                    .fontWeight(.bold)
                    .disabled(trimmedName.isEmpty || nameIsTaken)
                    .accessibilityLabel(isNew ? "createTag" : "confirm")
                }
            }
        }
        .task {
            // a new tag has nothing to look at yet, so start in the name field
            nameFocused = isNew
            loadChannels()
        }
        .onDisappear {
            guard !isNew else { return }
            // swiping the sheet away skips the confirm button, so the name is checked here too
            if trimmedName.isEmpty || nameIsTaken {
                tag.name = navigationName
            } else {
                tag.name = trimmedName
            }
            save()
        }
    }

    private var trimmedName: String {
        tag.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The library and saved shortcuts link to a tag by name.
    private var nameIsTaken: Bool {
        otherNames.contains(trimmedName.localizedLowercase)
    }

    /// Fetched, not queried: a re-emitting `@Query` drops the name field's focus.
    private func loadChannels() {
        let fetch = FetchDescriptor<Subscription>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\Subscription.title)]
        )
        subscriptions = (try? modelContext.fetch(fetch)) ?? []
        otherTagsBySubscription = fetchOtherTagsBySubscription()
        otherNames = Set(otherTags().map { $0.name.localizedLowercase })
    }

    /// Only the `include` tags: a badge from a subtractive one would read backwards.
    private func otherTags() -> [Tag] {
        let all = (try? modelContext.fetch(FetchDescriptor<Tag>(sortBy: [SortDescriptor(\.order)]))) ?? []
        return all.filter { $0.persistentModelID != tag.persistentModelID }
    }

    private func fetchOtherTagsBySubscription() -> [PersistentIdentifier: [TagBadge]] {
        var byId = [PersistentIdentifier: [TagBadge]]()
        for other in otherTags() where other.mode == .include {
            let badge = TagBadge(id: other.persistentModelID, name: other.name, symbol: other.displaySymbol)
            for subscription in other.subscriptions ?? [] {
                byId[subscription.persistentModelID, default: []].append(badge)
            }
        }
        return byId
    }

    private func isCovered(_ subscription: Subscription) -> Bool {
        isNew
            ? pendingSubscriptionIds.contains(subscription.persistentModelID)
            : tag.covers(subscription)
    }

    private func toggle(_ subscription: Subscription) {
        withAnimation {
            guard !isNew else {
                // linking an uninserted tag would insert it
                if !pendingSubscriptionIds.insert(subscription.persistentModelID).inserted {
                    pendingSubscriptionIds.remove(subscription.persistentModelID)
                }
                return
            }
            tag.setCovers(subscription, !tag.covers(subscription))
        }
        if !isNew {
            save()
        }
    }

    private func create() {
        tag.name = trimmedName
        guard !tag.name.isEmpty, !nameIsTaken else { return }

        tag.order = nextTagOrder
        withAnimation {
            modelContext.insert(tag)
        }
        tag.subscriptions = subscriptions.filter { pendingSubscriptionIds.contains($0.persistentModelID) }
        save()
        dismiss()
    }

    /// Skips `Int.max`, the model's default, which a restored tag can still carry.
    private var nextTagOrder: Int {
        let highest = otherTags().map(\.order).filter { $0 != Int.max }.max() ?? -1
        return min(highest, Int.max - 1) + 1
    }

    private func save() {
        try? modelContext.save()
    }

    private func delete() {
        modelContext.delete(tag)
        save()
        dismiss()
    }
}

#Preview {
    TagEditView(tag: Tag(name: "Tech"), isNew: true)
        .modelContainer(DataProvider.previewContainer)
}
