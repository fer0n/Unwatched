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

        if entry.video == nil, let youtubeId = entry.youtubeId {
            if let video = VideoService.getVideo(for: youtubeId, modelContext: modelContext) {
                if let queueEntry = entry as? QueueEntry {
                    if let duplicate = video.queueEntry {
                        if force {
                            modelContext.delete(duplicate)
                            video.queueEntry = queueEntry
                            Log.info("Moved video from duplicate queue entry to this one")
                        }
                    } else {
                        video.queueEntry = queueEntry
                        Log.info("Reconnected video to queue entry")
                    }
                }
                if let inboxEntry = entry as? InboxEntry {
                    if let duplicate = video.inboxEntry {
                        if force {
                            modelContext.delete(duplicate)
                            video.inboxEntry = inboxEntry
                            Log.info("Moved video from duplicate inbox entry to this one")
                        }
                    } else {
                        video.inboxEntry = inboxEntry
                        Log.info("Reconnected video to inbox entry")
                    }
                }
                try? modelContext.save()
            }
        } else {
            Log.info("Couldn't reconnect video to entry")
        }

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
