//
//  BackupSettingsSection.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct BackupSettings: View {
    @AppStorage(Const.automaticBackups) var automaticBackups = true
    @AppStorage(Const.includeUnimportantVideosInBackup) var includeUnimportantVideosInBackup = false
    @AppStorage(Const.includeStatsInBackup) var includeStatsInBackup = true
    @AppStorage(Const.includeWatchHistoryInBackup) var includeWatchHistoryInBackup = true

    var body: some View {
        MySection("automaticBackups", footer: "automaticBackupsHelper") {
            Toggle(isOn: $automaticBackups) {
                Text("backupToIcloud")
            }
        }

        MySection(footer: "minimalBackupsHelper") {
            Toggle(isOn: $includeWatchHistoryInBackup) {
                Text("includeWatchHistoryInBackup")
            }
            Toggle(isOn: $includeStatsInBackup) {
                Text("includeStatsInBackup")
            }
            Toggle(isOn: $includeUnimportantVideosInBackup) {
                Text("includeUnimportantVideosInBackup")
            }
        }
    }
}
