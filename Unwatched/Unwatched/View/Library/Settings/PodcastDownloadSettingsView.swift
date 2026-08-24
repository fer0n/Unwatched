//
//  PodcastDownloadSettingsView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct PodcastDownloadSettingsView: View {
    @AppStorage(Const.podcastDownloadLimitHours) var limitHours: Int = 0
    @AppStorage(Const.podcastDownloadKeepDays) var keepDays: Int = 1
    @AppStorage(Const.podcastDownloadOnCellular) var onCellular: Bool = false

    @State private var storedBytes: Int64 = 0
    @State private var isDeleting = false

    var body: some View {
        ZStack {
            MyBackgroundColor()

            MyForm {
                MySection(footer: "podcastDownloadsHelper") {
                    Picker("downloadAhead", selection: $limitHours) {
                        ForEach(Const.podcastDownloadHourOptions, id: \.self) { hours in
                            hourLabel(hours).tag(hours)
                        }
                    }
                    .pickerStyle(.menu)
                }

                MySection(footer: "deleteDownloadsHelper") {
                    Picker("deleteAfterWatching", selection: $keepDays) {
                        ForEach(Const.podcastDownloadKeepDayOptions, id: \.self) { days in
                            Text(keepLabel(days)).tag(days)
                        }
                    }
                    .pickerStyle(.menu)
                }

                MySection(footer: "downloadOnCellularHelper") {
                    Toggle(isOn: $onCellular) {
                        Text("downloadOnCellular")
                    }
                }

                if storedBytes > 0 {
                    MySection {
                        Button(role: .destructive) {
                            deleteAll()
                        } label: {
                            if isDeleting {
                                ProgressView()
                                    .frame(maxWidth: .infinity, alignment: .center)
                            } else {
                                LabeledContent("deleteAllDownloads") {
                                    Text(verbatim: storedBytes.formatted(.byteCount(style: .file)))
                                }
                            }
                        }
                    }
                }
            }
            .myNavigationTitle("podcastDownloads")
        }
        .onChange(of: limitHours) { sync() }
        .onChange(of: keepDays) { sync() }
        .onChange(of: onCellular) { sync() }
        .task { await refreshSize() }
    }

    @ViewBuilder
    private func hourLabel(_ hours: Int) -> some View {
        if hours == 0 {
            Text("off")
        } else if hours < 0 {
            Text("unlimited")
        } else {
            Text(
                Measurement(value: Double(hours), unit: UnitDuration.hours)
                    .formatted(.measurement(width: .abbreviated, usage: .asProvided))
            )
        }
    }

    private func keepLabel(_ days: Int) -> LocalizedStringKey {
        switch days {
        case 0: "immediately"
        case 1: "oneDay"
        default: "oneWeek"
        }
    }

    private func sync() {
        PodcastDownloadManager.shared.scheduleSync()
    }

    private func deleteAll() {
        guard !isDeleting else { return }
        isDeleting = true
        Task {
            await PodcastDownloadManager.shared.deleteAllDownloads()
            await refreshSize()
            isDeleting = false
        }
    }

    private func refreshSize() async {
        storedBytes = await Task.detached { PodcastDownloadStore.totalSize() }.value
    }
}

#Preview {
    PodcastDownloadSettingsView()
}
