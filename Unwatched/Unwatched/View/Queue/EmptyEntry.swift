//
//  EmptyEntry.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared
import OSLog

struct EmptyEntry<Entry>: View where Entry: PersistentModel & HasVideo {
    @Environment(PlayerManager.self) var player
    @Environment(\.modelContext) var modelContext
    @AppStorage(Const.themeColor) var theme = ThemeColor()

    @State var hasError = false
    @State var isLoading = false
    @State var showsDetails = false
    @State var repairFeedback: Task<Void, Never>?

    let entry: Entry

    init(_ entry: Entry) {
        self.entry = entry
    }

    var body: some View {
        ZStack {
            Button(action: toggleDetails) {
                VideoListItemPlaceholder()
                    .opacity(showsDetails ? 0 : 1)
                    .allowsHitTesting(false)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("emptyEntry")

            details
                .opacity(showsDetails ? 1 : 0)
                .allowsHitTesting(showsDetails)
                .disabled(!showsDetails)
                .accessibilityHidden(!showsDetails)
        }
        .task {
            reconnectVideo()
        }
        .onDisappear {
            showsDetails = false
            resetRepairFeedback()
        }
    }

    var details: some View {
        VStack {
            Text("emptyEntry")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .font(.body)
                .opacity(hasError ? 0 : 1)
                .overlay {
                    Text("emptyEntryError")
                        .foregroundStyle(.red)
                        .padding(.vertical, 3)
                        .opacity(hasError ? 1 : 0)
                }
                .allowsHitTesting(false)

            HStack {
                Button {
                    reconnectVideo(force: true)
                } label: {
                    Text("repair")
                        .opacity(isLoading ? 0 : 1)
                        .frame(maxWidth: .infinity)
                        .overlay {
                            if isLoading {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(theme.readableContrastColor)
                            }
                        }
                }
                .themeProminentButton(theme)

                Button {
                    clearEntry()
                } label: {
                    Text("remove")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity)
    }

    func toggleDetails() {
        withAnimation {
            showsDetails.toggle()
        }
    }

    func resetRepairFeedback() {
        repairFeedback?.cancel()
        isLoading = false
        hasError = false
    }

    func reconnectVideo(force: Bool = false) {
        if force {
            resetRepairFeedback()
            isLoading = true
        }

        attachVideo(force: force)

        if !force {
            return
        }

        repairFeedback = Task {
            do {
                try await Task.sleep(for: .seconds(1))
                withAnimation {
                    isLoading = false
                    hasError = true
                }
                try await Task.sleep(for: .seconds(2))
                withAnimation {
                    hasError = false
                }
            } catch { }
        }
    }

    func attachVideo(force: Bool) {
        guard entry.video == nil,
              let youtubeId = entry.youtubeId,
              let video = VideoService.getVideo(for: youtubeId, modelContext: modelContext) else {
            Log.info("Couldn't reconnect video to entry")
            return
        }

        let changesTopOfQueue = force && moveChangesTopOfQueue(video)
        if let queueEntry = entry as? QueueEntry {
            attach(queueEntry, to: video, via: \.queueEntry, force: force)
        } else if let inboxEntry = entry as? InboxEntry {
            attach(inboxEntry, to: video, via: \.inboxEntry, force: force)
        }
        try? modelContext.save()
        if changesTopOfQueue {
            player.loadTopmostVideoFromQueue(modelContext: modelContext)
        }
    }

    func moveChangesTopOfQueue(_ video: Video) -> Bool {
        guard let queueEntry = entry as? QueueEntry, let duplicate = video.queueEntry else {
            return false
        }
        return player.isTopOfQueue(order: duplicate.order, modelContext)
            || player.isTopOfQueue(order: queueEntry.order, modelContext)
    }

    func attach<Target: PersistentModel>(
        _ target: Target,
        to video: Video,
        via relationship: ReferenceWritableKeyPath<Video, Target?>,
        force: Bool
    ) {
        if let duplicate = video[keyPath: relationship] {
            guard force else { return }
            modelContext.delete(duplicate)
            Log.info("Moved video from duplicate entry to this one")
        } else {
            Log.info("Reconnected video to entry")
        }
        video[keyPath: relationship] = target
    }

    func clearEntry() {
        Log.info("Clear Entry")
        withAnimation {
            if let queueEntry = entry as? QueueEntry {
                let wasTopOfQueue = player.isTopOfQueue(order: queueEntry.order, modelContext)
                VideoService.deleteQueueEntry(queueEntry, modelContext: modelContext)
                if wasTopOfQueue {
                    player.loadTopmostVideoFromQueue()
                }
                return
            }
            if let inboxEntry = entry as? InboxEntry {
                VideoService.deleteInboxEntry(inboxEntry, modelContext: modelContext)
                return
            }
        }
    }
}
