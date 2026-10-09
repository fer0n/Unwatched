//
//  WarningsButton.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct WarningsButton: View {
    @Environment(NavigationManager.self) var navManager
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.openURL) var openURL
    private let openChapterSettings = OpenChapterSettingsAction()

    @State private var showPopover = false
    @State private var actionOnDismiss: (() -> Void)?

    private static var browserManager: BrowserManager { .shared }
    private static var chapterIssue: ChapterAutomationIssue? { ChapterAutomationStatus.shared.issue }

    static var hasWarnings: Bool {
        browserManager.youtubeLoginLost || chapterIssue != nil
    }

    var body: some View {
        Button {
            showPopover = true
        } label: {
            Image(systemName: Const.refreshWarningSF)
        }
        .accessibilityLabel("refreshWarning")
        .font(.footnote)
        .fontWeight(.bold)
        .myTint(neutral: true)
        .popover(isPresented: $showPopover) {
            VStack(alignment: .leading, spacing: 0) {
                if Self.browserManager.youtubeLoginLost {
                    youtubeLoginWarning
                }
                if let issue = Self.chapterIssue {
                    if Self.browserManager.youtubeLoginLost {
                        Divider()
                    }
                    chapterWarning(issue)
                }
            }
            .presentationCompactAdaptation(.popover)
            .environment(\.colorScheme, colorScheme)
            // a sheet or window can't be presented while the popover is still dismissing
            .onDisappear {
                actionOnDismiss?()
                actionOnDismiss = nil
            }
        }
        .onChange(of: Self.hasWarnings) {
            if !Self.hasWarnings {
                showPopover = false
            }
        }
    }

    private var youtubeLoginWarning: some View {
        WarningPopoverContent(
            systemImage: "person.crop.circle.badge.exclamationmark",
            title: "youtubeLoginLost",
            message: Text("youtubeLoginLostMessage")
        ) {
            Button("dismissHint") {
                Self.browserManager.dismissYoutubeLoginLost()
            }
            .buttonStyle(.bordered)
            Button("youtubeLoginAgain") {
                closeThen {
                    navManager.openBrowser(.url(UrlService.youtubeLoginUrl.absoluteString))
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func chapterWarning(_ issue: ChapterAutomationIssue) -> some View {
        WarningPopoverContent(systemImage: "sparkles", title: issue.title, message: issue.message) {
            if issue.isDismissible {
                Button("dismissHint") {
                    ChapterAutomationStatus.shared.dismiss()
                }
                .buttonStyle(.bordered)
            }
            if let actionTitle = issue.actionTitle {
                Button(actionTitle) {
                    closeThen {
                        issue.resolve(openURL: openURL, openChapterSettings: openChapterSettings)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func closeThen(_ action: @escaping () -> Void) {
        actionOnDismiss = action
        showPopover = false
    }
}
