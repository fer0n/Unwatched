//
//  YoutubeLoginWarningButton.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct YoutubeLoginWarningButton: View {
    @Environment(NavigationManager.self) var navManager
    @Environment(\.colorScheme) var colorScheme

    @State private var showPopover = false
    @State private var logInOnDismiss = false

    private var browserManager: BrowserManager { .shared }

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
            YoutubeLoginWarningPopoverContent(
                onLogin: logIn,
                onDismissLoginLost: dismissLoginLost
            )
            .presentationCompactAdaptation(.popover)
            .environment(\.colorScheme, colorScheme)
            // the browser sheet can't be presented while the popover is still dismissing
            .onDisappear {
                guard logInOnDismiss else { return }
                logInOnDismiss = false
                navManager.openBrowser(.url(UrlService.youtubeLoginUrl.absoluteString))
            }
        }
    }

    private func logIn() {
        logInOnDismiss = true
        showPopover = false
    }

    private func dismissLoginLost() {
        showPopover = false
        browserManager.dismissYoutubeLoginLost()
    }
}

struct YoutubeLoginWarningPopoverContent: View {
    var onLogin: () -> Void
    var onDismissLoginLost: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text("youtubeLoginLost")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("youtubeLoginLostMessage")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("dismissHint", action: onDismissLoginLost)
                        .buttonStyle(.bordered)
                    Button("youtubeLoginAgain", action: onLogin)
                        .buttonStyle(.borderedProminent)
                }
                .padding(.top, 10)
                .myTint()
            }
        }
        // the button's bold carries over otherwise
        .fontWeight(.regular)
        .fixedSize(horizontal: false, vertical: true)
        .frame(idealWidth: 300, maxWidth: 300, alignment: .leading)
        .padding()
    }
}

#Preview {
    YoutubeLoginWarningPopoverContent(
        onLogin: {},
        onDismissLoginLost: {}
    )
}
