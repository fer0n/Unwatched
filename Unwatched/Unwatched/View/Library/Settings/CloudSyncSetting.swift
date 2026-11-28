//
//  CloudSyncSetting.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct CloudSyncSetting: View {
    @AppStorage(Const.enableIcloudSync) var enableIcloudSync = false
    @AppStorage(Const.autoRefreshIgnoresSync) var autoRefreshIgnoresSync: Bool = false

    @State var showRestartOption = false

    var body: some View {
        MySection("icloudSync", footer: "icloudSyncHelper") {
            Toggle(isOn: $enableIcloudSync.animation()) {
                Text("syncToIcloud")
            }
            .onChange(of: enableIcloudSync) {
                showRestartOption = true
            }
        }
        .confirmationDialog(
            "restartNow?",
            isPresented: $showRestartOption,
            titleVisibility: .visible,
            actions: {
                Button("restartNow", role: .destructive) {
                    exit(0)
                }
                Button("cancel", role: .cancel) { }
            }, message: {
                Text("icloudSyncHelper")
            }
        )

        if enableIcloudSync {
            MySection(footer: "allowRefreshDuringSyncFooter") {
                Toggle(isOn: $autoRefreshIgnoresSync) {
                    Text("autoRefreshIgnoresSync")
                }
            }
        }
    }
}
