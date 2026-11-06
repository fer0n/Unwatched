//
//  PodcastDownloadSettingsView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct PodcastDownloadSettingsView: View {
    @AppStorage(Const.podcastDownloadLimitHours) var limitHours = Const.podcastDownloadDefaultHours
    @AppStorage(Const.podcastDownloadKeepDays) var keepDays = Const.podcastDownloadDefaultKeepDays
    @AppStorage(Const.podcastDownloadCellularHours) var cellularHours = Const.podcastDownloadDefaultCellularHours

    @State private var storedBytes: Int64 = 0
    @State private var isDeleting = false

    var body: some View {
        ZStack {
            MyBackgroundColor()

            MyForm {
                MySection(footer: "podcastDownloadsHelper") {
                    hoursPicker("downloadAhead", selection: $limitHours)
                }

                MySection(footer: "downloadOnCellularHelper") {
                    hoursPicker("downloadOnCellular", selection: $cellularHours)
                        .disabled(limitHours == 0)
                }

                MySection(footer: "deleteDownloadsHelper") {
                    Picker("deleteAfterWatching", selection: $keepDays) {
                        ForEach(Const.podcastDownloadKeepDayOptions, id: \.self) { days in
                            Text(keepLabel(days)).tag(days)
                        }
                    }
                    .pickerStyle(.menu)
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
            .animation(.default, value: storedBytes > 0)
            .myNavigationTitle("podcastDownloads")
        }
        .onChange(of: limitHours) { sync() }
        .onChange(of: keepDays) { sync() }
        .onChange(of: cellularHours) { sync() }
        .task { await refreshSize() }
    }

    private func hoursPicker(_ title: LocalizedStringKey, selection: Binding<Int>) -> some View {
        Picker(title, selection: selection) {
            ForEach(Const.podcastDownloadHourOptions, id: \.self) { hours in
                hourLabel(hours).tag(hours)
            }
        }
        .pickerStyle(.menu)
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
