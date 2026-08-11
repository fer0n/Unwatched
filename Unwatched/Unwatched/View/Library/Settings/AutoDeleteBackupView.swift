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
    @State var countRecompressedBackups: Int?
    @State var showDeleteConfirmation: Bool = false
    @State var isRunning = false

    var body: some View {
        MySection(footer: "autoDeleteHelper") {
            Toggle(isOn: $autoDeleteBackups) {
                Text("autoDeleteBackups")
            }
            Button(role: .destructive, action: {
                showDeleteConfirmation = true
            }, label: {
                if isRunning {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    Text("autoDeleteBackupsNow")
                }
            })
            if let count = countDeletedVideos {
                Text("autoDeletedCount: \(count)")
            }
            if let count = countRecompressedBackups {
                Text("autoRecompressedCount: \(count)")
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
        guard !isRunning else { return }
        withAnimation {
            countDeletedVideos = nil
            countRecompressedBackups = nil
            isRunning = true
        }
        Task {
            let result = await UserDataService.autoDeleteBackups()
            withAnimation {
                countDeletedVideos = result.deleted
                countRecompressedBackups = result.recompressed
                isRunning = false
            }
        }
    }
}
