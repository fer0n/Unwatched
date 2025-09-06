//
//  DeleteEverythingExceptSubsButton.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import OSLog
import UnwatchedShared

struct DeleteEverythingExceptSubsButton: View {
    @Environment(PlayerManager.self) var player
    @Environment(\.modelContext) var modelContext

    @State var isDeletingTask: Task<(), Never>?
    @State var showConfirmation = false

    var body: some View {
        Button(role: .destructive, action: {
            showConfirmation = true
        }, label: {
            if isDeletingTask != nil {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Text("deleteEverythingExceptSubs")
            }
        })
        .confirmationDialog("reallyDelete",
                            isPresented: $showConfirmation,
                            titleVisibility: .visible,
                            actions: {
                                Button("confirm", role: .destructive) {
                                    deleteEverythingExceptSubs()
                                }
                                Button("cancel", role: .cancel) { }
                            })
        .task(id: isDeletingTask) {
            guard isDeletingTask != nil else { return }
            await isDeletingTask?.value
            isDeletingTask = nil
        }
    }

    func deleteEverythingExceptSubs() {
        if isDeletingTask != nil { return }

        withAnimation {
            player.clearVideo(modelContext)
            player.video = nil
        }

        isDeletingTask = Task {
            let context = DataProvider.newContext()
            do {
                let subscriptionsDescriptor = FetchDescriptor<Subscription>()
                if let subscriptions = try? context.fetch(subscriptionsDescriptor) {
                    for subscription in subscriptions {
                        subscription.mostRecentVideoDate = nil
                    }
                }
                try context.save()
                await CleanupService.deleteEverything(except: Subscription.self)
            } catch {
                Log.error("Failed to delete everything except subscriptions: \(error)")
            }

            _ = ImageService.deleteAllImages()
            _ = TranscriptService.deleteCache()
        }
    }
}
