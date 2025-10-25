//
//  DebugLoggerView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct DebugLoggerView: View {
    @AppStorage(Const.enableLogging) private var enableLogging: Bool = false
    @State var showConfirmation = false

    var body: some View {
        MySection("logs") {
            Toggle(isOn: $enableLogging) {
                Text("logging")
            }
            .onChange(of: enableLogging) {
                Log.setIsEnabled(enableLogging)
            }
            .tint(.red)

            if let logFile = Log.logFile {
                ShareLink(
                    item: logFile,
                    subject: Text(verbatim: "Unwatched Logs"),
                    preview: SharePreview(Text(verbatim: "Unwatched.log"), icon: Image(systemName: "book.pages.fill"))
                ) {
                    Text("exportLogs")
                }
            }
        }

        MySection {
            Button(role: .destructive) {
                showConfirmation = true
            } label: {
                Text("deleteLogs")
            }
        }
        .confirmationDialog(
            "reallyDelete",
            isPresented: $showConfirmation,
            titleVisibility: .visible,
            actions: {
                Button("confirm", role: .destructive) {
                    Log.deleteLogFile()
                }
                Button("cancel", role: .cancel) { }
            }
        )

    }
}
