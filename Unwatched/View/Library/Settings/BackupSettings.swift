//
//  BackupSettingsSection.swift
//  Unwatched
//

import SwiftUI

struct BackupSettings: View {
    @AppStorage(Const.automaticBackups) var automaticBackups = true
    @AppStorage(Const.minimalBackups) var minimalBackups = true
    @AppStorage(Const.enableIcloudSync) var enableIcloudSync = false
    @AppStorage(Const.exludeWatchHistoryInBackup) var exludeWatchHistoryInBackup = false

    var body: some View {
        MySection("icloudSync", footer: "icloudSyncHelper") {
            Toggle(isOn: $enableIcloudSync) {
                Text("syncToIcloud")
            }
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
