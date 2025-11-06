//
//  BackupSettingsSection.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct BackupSettings: View {
    @AppStorage(Const.automaticBackups) var automaticBackups = true
    @AppStorage(Const.minimalBackups) var minimalBackups = true
    @AppStorage(Const.exludeWatchHistoryInBackup) var exludeWatchHistoryInBackup = false

    var body: some View {
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
