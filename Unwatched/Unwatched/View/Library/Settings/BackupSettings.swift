//
//  BackupSettingsSection.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct BackupSettings: View {
    @AppStorage(Const.automaticBackups) var automaticBackups = true
    @AppStorage(Const.minimalBackups) var minimalBackups = true
    @AppStorage(Const.enableIcloudSync) var enableIcloudSync = false
    @AppStorage(Const.exludeWatchHistoryInBackup) var exludeWatchHistoryInBackup = false

    @State var showRestartOption = false

    var body: some View {
        MySection("icloudSync", footer: "icloudSyncHelper") {
            Toggle(isOn: $enableIcloudSync) {
                Text("syncToIcloud")
            }
            .onChange(of: enableIcloudSync) {
                showRestartOption = true
            }
        }
        .actionSheet(isPresented: $showRestartOption) {
            ActionSheet(title: Text("restartNow?"),
                        message: Text("icloudSyncHelper"),
                        buttons: [
                            .destructive(Text("restartNow")) {
                                exit(0)
                            },
                            .cancel()
                        ])
        }

        MySection("automaticBackups", footer: "automaticBackupsHelper") {
            Toggle(isOn: $automaticBackups) {
                Text("backupToIcloud")
            }
        }

        MySection(footer: "minimalBackupsHelper") {
            Toggle(isOn: $exludeWatchHistoryInBackup) {
                Text("exludeWatchHistoryInBackup")
            }
            Toggle(isOn: $minimalBackups) {
                Text("minimalBackups")
            }
        }
    }
}
