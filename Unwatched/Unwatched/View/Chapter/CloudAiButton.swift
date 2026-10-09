//
//  CloudAiButton.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct CloudAiButton<Label: View>: View {
    @Environment(AppNotificationVM.self) var appNotificationVM
    @Environment(\.dismiss) var dismiss
    private let openChapterSettings = OpenChapterSettingsAction()

    let video: Video?
    var dismissOnPaywall: Bool = false
    @ViewBuilder var label: () -> Label

    var body: some View {
        Button {
            guard guardPremium(onInteraction: dismissOnPaywall ? { dismiss() } : nil) else { return }
            Task {
                guard let video, await ChapterAutomation.isSetUp() else {
                    openChapterSettings()
                    return
                }
                do {
                    try await ChapterAutomation.loadTranscript(video)
                    await ChapterAutomation.sendNotification(for: video)
                } catch {
                    appNotificationVM.show(error.localizedDescription, isError: true)
                }
            }
        } label: {
            label()
        }
    }
}
