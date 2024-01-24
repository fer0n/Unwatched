//
//  InboxView.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct InboxView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(NavigationManager.self) private var navManager
    @Query(sort: \InboxEntry.video?.publishedDate, order: .reverse) var inboxEntries: [InboxEntry]
    @State private var showingClearAllAlert = false

    var body: some View {
        @Bindable var navManager = navManager

        NavigationStack(path: $navManager.presentedSubscriptionInbox) {
            ZStack {
                if inboxEntries.isEmpty {
                    ContentUnavailableView("noInboxItems",
                                           systemImage: "tray.fill",
                                           description: Text("noInboxItemsDescription"))
                        .contentShape(Rectangle())
                        .dropDestination(for: URL.self) { items, _ in
                            handleUrlDrop(items)
                            return true
                        }
                } else {
                    List {
                        ForEach(inboxEntries) { entry in
                            ZStack {
                                if let video = entry.video {
                                    VideoListItem(
                                        video: video,
                                        videoSwipeActions: [.queueTop, .queueBottom, .clear],
                                        onClear: {
                                            VideoService.deleteInboxEntry(
                                                entry,
                                                modelContext: modelContext
                                            )
                                        }
                                    )
                                }
                            }
                        }
                        .dropDestination(for: URL.self) { items, _ in
                            handleUrlDrop(items)
                        }
                        if inboxEntries.count > Const.minInboxEntriesToShowClear {
                            clearAllButton
                                .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .toolbar {
                RefreshToolbarButton()
            }
            .navigationTitle("inbox")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Subscription.self) { sub in
                SubscriptionDetailView(subscription: sub)
            }
        }
        .alert("confirmClearAll", isPresented: $showingClearAllAlert, actions: {
            Button("clearAll", role: .destructive) {
                clearAll()
            }
            Button("cancel", role: .cancel) {}
        }, message: {
            Text("areYouSureClearAll")
        })
    }

    func deleteInboxEntryIndexSet(_ indexSet: IndexSet) {
        for index in indexSet {
            let entry = inboxEntries[index]
            deleteInboxEntry(entry)
        }
    }

    func deleteInboxEntry(_ entry: InboxEntry) {
        VideoService.deleteInboxEntry(entry, modelContext: modelContext)
    }

    func handleUrlDrop(_ items: [URL]) {
        print("handleUrlDrop inbox", items)
        _ = VideoService.addForeignUrls(items, in: .inbox, modelContext: modelContext)
    }

    func clearAll() {
        VideoService.deleteInboxEntries(inboxEntries, modelContext: modelContext)
    }

    var clearAllButton: some View {
        Button {
            showingClearAllAlert = true
        } label: {
            HStack {
                Spacer()
                Image(systemName: Const.clearSF)
                    .resizable()
                    .frame(width: 30, height: 30)
                    .foregroundColor(.teal)
                Spacer()
            }.padding()
        }
    }

}

#Preview {
    InboxView()
        .modelContainer(DataController.previewContainer)
        .environment(NavigationManager())
        .environment(PlayerManager())
        .environment(RefreshManager())
}
