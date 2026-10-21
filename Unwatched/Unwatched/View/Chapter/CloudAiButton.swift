//
//  CloudAiButton.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct CloudAiButton<Label: View>: View {
    @Environment(AppNotificationVM.self) var appNotificationVM
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL
    private let openChapterSettings = OpenChapterSettingsAction()

    let video: Video?
    var dismissOnPaywall: Bool = false
    @ViewBuilder var label: () -> Label

    var body: some View {
        Button {
            guard guardPremium(onInteraction: dismissOnPaywall ? { dismiss() } : nil) else { return }
            Task {
                guard let video, await ChapterAutomation.isSetUp() else {
                    if ChapterAutomation.isAutomationEnabled && ChapterAutomation.isShortcutOutdated {
                        openURL(ChapterAutomation.installShortcut())
                    } else {
                        openChapterSettings()
                    }
                    return
                }
                do {
                    try await ChapterAutomation.loadTranscript(video, generateIfMissing: true)
                    await ChapterAutomation.sendNotification(for: video)
                } catch is CancellationError {
                } catch {
                    appNotificationVM.show(error.localizedDescription, isError: true)
                }
            }
        } label: {
            label()
        }
    }
}
