//
//  WatchDownloadsSection.swift
//  UnwatchedWatch
//

import SwiftData
import SwiftUI
import UnwatchedShared

/// Episodes only: a YouTube video's stream URL is minted per playback and expires.
struct WatchDownloadsSection: View {
    /// Per device, like the phone's: `UserDefaults` doesn't sync, and a wrist has its own room.
    @AppStorage(Const.podcastDownloadLimitHours) private var downloadHours = 0
    @Environment(\.modelContext) private var modelContext
    @State private var downloads = PodcastDownloadManager.shared
    @State private var downloadedBytes: Int64 = 0

    var body: some View {
        Section {
            Picker("watchDownloadAhead", selection: $downloadHours) {
                ForEach(Const.watchPodcastDownloadHourOptions, id: \.self) { hours in
                    hourLabel(hours).tag(hours)
                }
            }
            .pickerStyle(.navigationLink)

            if !downloads.downloadProgress.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "progress.indicator")
                        .symbolEffect(.variableColor.iterative)
                    Text("watchDownloading")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            if downloadedBytes > 0 {
                Button(role: .destructive) {
                    Task {
                        await downloads.deleteAllDownloads()
                        await refreshDownloadedSize()
                    }
                } label: {
                    HStack {
                        Text("watchDeleteDownloads")
                        Spacer(minLength: 2)
                        Text(verbatim: downloadedBytes.formatted(.byteCount(style: .file)))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } footer: {
            Text("watchDownloadAheadFooter")
        }
        .task(id: downloadHours) {
            downloads.scheduleSync(planning: modelContext)
        }
        .task(id: downloads.downloadedIds) {
            await refreshDownloadedSize()
        }
    }

    @ViewBuilder
    private func hourLabel(_ hours: Int) -> some View {
        if hours == 0 {
            Text("watchDownloadsOff")
        } else {
            Text(
                Measurement(value: Double(hours), unit: UnitDuration.hours)
                    .formatted(.measurement(width: .abbreviated, usage: .asProvided))
            )
        }
    }

    private func refreshDownloadedSize() async {
        downloadedBytes = await Task.detached { PodcastDownloadStore.totalSize() }.value
    }
}
