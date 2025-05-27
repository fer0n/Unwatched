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

    @State var isVisible = false
    @State var hasError = false
    @State var isLoading = false

    let entry: Entry

    init(_ entry: Entry) {
        self.entry = entry
    }

    var body: some View {
        Color.backgroundColor

        ZStack {
            Color.insetBackground

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

                HStack {
                    Button {
                        reconnectVideo(force: true)
                    } label: {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .tint(theme.darkContrastColor)
                        } else {
                            Text("repair")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)

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
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .scaleEffect(isVisible ? 1 : 0.9)
        .opacity(isVisible ? 1 : 0)
        .task {
            reconnectVideo()
        }
        .task {
            do {
                try await Task.sleep(for: .seconds(1))
                withAnimation {
                    isVisible = true
                }
            } catch { }
        }
    }

    func reconnectVideo(force: Bool = false) {
        if force {
            hasError = false
            isLoading = true
        }

        if entry.video == nil, let youtubeId = entry.youtubeId {
            if let video = VideoService.getVideo(for: youtubeId, modelContext: modelContext) {
                if let queueEntry = entry as? QueueEntry {
                    if video.queueEntry == nil || force {
                        video.queueEntry = queueEntry
                        Log.info("Reconnected video to queue entry")
                    } else {
                        // there already is an entry, but it's not this one
                        // which means it's a duplicate or is still syncing
                    }
                }
                if let inboxEntry = entry as? InboxEntry {
                    if video.inboxEntry == nil || force {
                        video.inboxEntry = inboxEntry
                        Log.info("Reconnected video to inbox entry")
                    } else {
                        // there already is an entry, but it's not this one
                        // which means it's a duplicate or is still syncing
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

        Task {
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
            isLoading = false
        }
    }

    func clearEntry() {
        Log.info("Clear Entry")
        withAnimation {
            if let queueEntry = entry as? QueueEntry {
                VideoService.deleteQueueEntry(queueEntry, modelContext: modelContext)
                if queueEntry.order == 0 {
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
