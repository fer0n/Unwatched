//
//  DebugView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct DebugView: View {
    @AppStorage(Const.monitorBackgroundFetchesNotification) var monitorBackgroundFetches: Bool = false
    @AppStorage(Const.showTutorial) var showTutorial: Bool = true
    @AppStorage(Const.backgroundPlayback) var backgroundPlayback: Bool = true

    @Environment(\.modelContext) var modelContext
    @Environment(PlayerManager.self) var player

    #if os(iOS)
    @Environment(Alerter.self) var alerter
    #endif

    var body: some View {
        ZStack {
            MyBackgroundColor(macOS: false)

            MyForm {
                MySection {
                    Button {
                        showTutorial = true
                        player.video = nil
                    } label: {
                        Text("showTutorial")
                    }
                    .disabled(showTutorial == true && player.video == nil)
                }

                MySection("notifications") {
                    Toggle(isOn: $monitorBackgroundFetches) {
                        Text("monitorBackgroundFetches")
                    }
                }

                #if os(iOS)
                MySection("playback") {
                    Toggle(isOn: $backgroundPlayback) {
                        Text("backgroundPlayback")
                    }
                }
                #endif

                MySection {
                    Button("createTestWatchData", action: createTestWatchData)
                }

                CleanupHiddenShortsView()

                DebugLoggerView()
            }
        }
        #if os(iOS)
        .task(id: monitorBackgroundFetches) {
            if monitorBackgroundFetches {
                do {
                    try await NotificationManager.askNotificationPermission()
                } catch {
                    alerter.showError(error)
                }
            }
        }
        #endif
        .myNavigationTitle("debug")
    }

    private func createTestWatchData() {
        let channelIds = ["channel1", "channel2", "channel3"]
        let calendar = Calendar.current

        for _ in 0..<10 {
            let randomChannel = channelIds.randomElement()!
            let randomTime = TimeInterval.random(in: 60...3600)
            // Random date within last 30 days
            let randomDays = Int.random(in: 0...10)
            let date = calendar.date(byAdding: .day, value: -randomDays, to: Date())!

            let entry = WatchTimeEntry(date: date, channelId: randomChannel, watchTime: randomTime)
            modelContext.insert(entry)
        }
        try? modelContext.save()
    }
}

#Preview {
    DebugView()
        .modelContainer(DataProvider.previewContainer)
        .environment(Alerter())
        .environment(PlayerManager())
}
