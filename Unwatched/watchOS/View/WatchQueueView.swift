//
//  WatchQueueView.swift
//  UnwatchedWatch
//

import SwiftData
import SwiftUI
import UnwatchedShared

/// The queue, in the order the phone put it in, narrowed to one tag at a time.
struct WatchQueueView: View {
    @Environment(WatchNavigator.self) private var navigator

    @Query(sort: \Tag.order) private var tags: [Tag]
    /// The name rather than the model: it survives relaunch, and a missing tag falls back to "all".
    @AppStorage(Const.watchSelectedTagName) private var selectedTagName = ""
    @State private var isPickingTag = false

    private var selectedTag: Tag? {
        tags.first { $0.name == selectedTagName }
    }

    private var selectedTagBinding: Binding<Tag?> {
        Binding(
            get: { selectedTag },
            set: { selectedTagName = $0?.name ?? "" }
        )
    }

    var body: some View {
        // Re-created when the tag changes so `@Query` picks up the new descriptor.
        QueueList(filter: QueueFilter(tag: selectedTag, in: tags), tagName: selectedTag?.name)
            .id(selectedTag?.persistentModelID)
            .toolbar {
                // Here rather than on the player page because it decides what a tapped row does.
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        navigator.controlsPhone.toggle()
                    } label: {
                        Image(systemName: navigator.controlsPhone ? "iphone" : "applewatch")
                    }
                    .tint(nil)
                }

                if !tags.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isPickingTag = true
                        } label: {
                            Image(systemName: selectedTag?.displaySymbol ?? "line.3.horizontal.decrease")
                        }
                        .tint(nil)
                    }
                }
            }
            .sheet(isPresented: $isPickingTag) {
                // watchOS has no `Menu`, so the tags get a list of their own.
                TagPicker(tags: tags, selected: selectedTagBinding)
            }
    }
}

private struct TagPicker: View {
    let tags: [Tag]
    @Binding var selected: Tag?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            row(nil, name: String(localized: "watchAllVideos"), symbol: "list.bullet")
            ForEach(tags) { tag in
                row(tag, name: tag.name, symbol: tag.displaySymbol)
            }
        }
        .navigationTitle("watchFilter")
    }

    private func row(_ tag: Tag?, name: String, symbol: String) -> some View {
        Button {
            selected = tag
            dismiss()
        } label: {
            HStack {
                Label(name, systemImage: symbol)
                Spacer(minLength: 0)
                if tag?.persistentModelID == selected?.persistentModelID {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
        }
    }
}

/// Split out so the `@Query` can take the filter's descriptor through `init`.
private struct QueueList: View {
    @Environment(WatchAudioPlayer.self) private var player
    @Environment(WatchNavigator.self) private var navigator
    @Environment(SyncManager.self) private var syncer
    @Environment(SyncProgress.self) private var progress
    @State private var client = WatchQueueClient.shared
    @Query private var entries: [QueueEntry]

    /// Shown as the section's title: the bar has no room for it once the queue is a tab.
    let tagName: String?

    init(filter: QueueFilter, tagName: String?) {
        _entries = Query(filter.descriptor())
        self.tagName = tagName
    }

    var body: some View {
        if entries.isEmpty && player.video == nil {
            WatchSyncView(showsEmptyQueueNote: true)
        } else {
            list
        }
    }

    private var list: some View {
        List {
            nowPlaying

            if let tagName {
                Section(tagName) {
                    queueRows
                }
            } else {
                queueRows
            }

            Section {
                syncRow
            }
        }
    }

    /// Pinned above the queue, so getting back to what's playing never depends on scrolling.
    @ViewBuilder
    private var nowPlaying: some View {
        if navigator.controlsPhone, let remote = client.remote, !remote.isEmpty {
            Section("watchNowPlaying") {
                Button {
                    navigator.tab = .player
                } label: {
                    WatchQueueRow(remote: remote)
                }
            }
        } else if !navigator.controlsPhone, let video = player.video {
            Section("watchNowPlaying") {
                Button {
                    navigator.tab = .player
                } label: {
                    WatchQueueRow(video: video, isCurrent: true)
                }
            }
        }
    }

    private var queueRows: some View {
        ForEach(entries) { entry in
            if let video = entry.video, navigator.controlsPhone || video.persistentModelID != player.video?.persistentModelID {
                Button {
                    if navigator.controlsPhone {
                        Task { await client.send(.play(video.youtubeId)) }
                    } else {
                        player.play(video)
                    }
                    navigator.tab = .player
                } label: {
                    WatchQueueRow(video: video, isCurrent: false)
                }
            }
        }
    }

    /// A partly-imported queue looks like a complete one; this says more is still coming.
    private var syncRow: some View {
        NavigationLink {
            WatchSyncView()
        } label: {
            Group {
                if progress.isImporting(isSyncing: syncer.isSyncing) {
                    SyncingLabel(isImporting: true, share: progress.share(of: client.totals))
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "gearshape")
                        Text("watchSettings")
                    }
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
        }
    }
}
