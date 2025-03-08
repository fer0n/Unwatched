//
//  AutoDeleteBackupView.swift
//  Unwatched
//

import Foundation
import SwiftUI
import UnwatchedShared

struct AutoDeleteBackupView: View {
    @AppStorage(Const.autoDeleteBackups) var autoDeleteBackups = true
    @State var countDeletedVideos: Int?
    @State var showDeleteConfirmation: Bool = false

    var body: some View {
        MySection(footer: "autoDeleteHelper") {
            Toggle(isOn: $autoDeleteBackups) {
                Text("autoDeleteBackups")
            }
            Button(role: .destructive, action: {
                showDeleteConfirmation = true
            }, label: {
                Text("autoDeleteBackupsNow")
            })
            if let count = countDeletedVideos {
                Text("autoDeletedCount: \(count)")
            }
        }
        .confirmationDialog("confirmAutoDeleteBackup",
                            isPresented: $showDeleteConfirmation,
                            titleVisibility: .visible,
                            actions: {
                                Button("autoDeleteBackupsNow", role: .destructive) { autoDeleteNow() }
                                Button("cancel", role: .cancel) { }
                            }, message: {
                                Text("autoDeleteHelper")
                            })
    }

    func autoDeleteNow() {
        withAnimation {
            countDeletedVideos = nil
            countDeletedVideos = UserDataService.autoDeleteBackups()
        }
    }
}
