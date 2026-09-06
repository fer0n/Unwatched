//
//  WatchQueueView.swift
//  UnwatchedWatch
//

import SwiftData
import SwiftUI
import UnwatchedShared

/// The queue, in the order the phone put it in, narrowed to one tag at a time.
struct WatchQueueView: View {
    @Environment(WatchAudioPlayer.self) var player

    @Query(sort: \Tag.order) private var tags: [Tag]
    /// The name rather than the model itself: it survives relaunch without needing a
    /// `PersistentIdentifier` round trip, and a renamed or deleted tag just falls back to "all".
    @AppStorage("watchSelectedTagName") private var selectedTagName = ""
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
        // Re-created when the tag changes so `@Query` picks up the new descriptor; the list itself
        // is small enough on a watch that rebuilding it costs nothing.
        QueueList(filter: QueueFilter(tag: selectedTag, in: tags), tagName: selectedTag?.name)
            .id(selectedTag?.persistentModelID)
            .toolbar {
                if !tags.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isPickingTag = true
                        } label: {
                            Image(systemName: selectedTag?.displaySymbol ?? "line.3.horizontal.decrease")
                        }
                    }
                }
            }
            .sheet(isPresented: $isPickingTag) {
                // watchOS has no `Menu`, so the tags get a pushed list of their own.
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
    @Environment(WatchAudioPlayer.self) var player
    @Environment(WatchNavigator.self) var navigator
    @Environment(SyncManager.self) var syncer
    @Query private var entries: [QueueEntry]
    @State private var isShowingSyncDetail = false

    /// The tag's own name, shown as this section's title instead of the navigation bar's — the
    /// bar has no room for it once the queue is a tab rather than a pushed screen.
    let tagName: String?

    init(filter: QueueFilter, tagName: String?) {
        _entries = Query(filter.descriptor())
        self.tagName = tagName
    }

    var body: some View {
        List {
            // Pinned above the queue so getting back to what's already playing never depends on
            // scrolling to find its row again.
            if let nowPlaying = player.video {
                Section("watchNowPlaying") {
                    Button {
                        navigator.tab = .player
                    } label: {
                        QueueRow(video: nowPlaying, isCurrent: true)
                    }
                }
            }

            if let tagName {
                Section(tagName) {
                    queueRows
                }
            } else {
                queueRows
            }

            // A partly-imported queue looks like a complete one; this says more is still coming,
            // and leads to the same breakdown the empty queue shows.
            if syncer.isSyncing && !entries.isEmpty {
                Button {
                    isShowingSyncDetail = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "progress.indicator")
                            .symbolEffect(.variableColor.iterative)
                        Text("watchSyncingShort")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .overlay {
            if entries.isEmpty && player.video == nil {
                QueueEmptyView()
            }
        }
        .sheet(isPresented: $isShowingSyncDetail) {
            SyncDetailView()
        }
    }

    private var queueRows: some View {
        ForEach(entries) { entry in
            if let video = entry.video, video.persistentModelID != player.video?.persistentModelID {
                Button {
                    player.play(video)
                    navigator.tab = .player
                } label: {
                    QueueRow(video: video, isCurrent: false)
                }
            }
        }
    }
}

struct QueueRow: View {
    let video: Video
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 8) {
            thumbnail

            VStack(alignment: .leading, spacing: 2) {
                Text(video.title)
                    .font(.footnote)
                    .lineLimit(2)
                if let channel = video.subscription?.title {
                    Text(channel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            if isCurrent {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.caption2)
                    .foregroundStyle(.tint)
            }
        }
    }

    private var thumbnail: some View {
        Color.gray.opacity(0.3)
            .overlay {
                ArtworkFill(
                    url: video.displayThumbnailUrl,
                    isSquare: video.isAudioOnly == true,
                    maxPixelSize: 160
                )
            }
            .frame(width: Self.side, height: Self.side)
            .clipShape(.rect(cornerRadius: 5))
    }

    private static let side: CGFloat = 44
}
