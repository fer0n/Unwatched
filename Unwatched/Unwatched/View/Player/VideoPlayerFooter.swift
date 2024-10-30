//
//  VideoPlayerFooter.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct VideoPlayerFooter: View {
    @Environment(NavigationManager.self) var navManager
    @Environment(\.modelContext) var modelContext
    @Environment(PlayerManager.self) var player
    @State var hapticToggle: Bool = false

    var openBrowserUrl: (BrowserUrl) -> Void
    var setShowMenu: (() -> Void)?
    var sleepTimerVM: SleepTimerViewModel
    var onSleepTimerEnded: (Double?) -> Void

    var body: some View {
        HStack {
            if let video = player.video {
                SleepTimer(viewModel: sleepTimerVM, onEnded: onSleepTimerEnded)
                    .frame(maxWidth: .infinity)

                Button(action: toggleBookmark) {
                    Image(systemName: video.bookmarkedDate != nil
                            ? "bookmark.fill"
                            : "bookmark.slash")
                        .contentTransition(.symbolEffect(.replace))
                }

                .frame(maxWidth: .infinity)
            }

            if let setShowMenu = setShowMenu {
                Button {
                    setShowMenu()
                } label: {
                    VStack {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 30))
                            .fontWeight(.regular)
                        Text("showMenu")
                            .font(.caption)
                            .textCase(.uppercase)
                            .padding(.bottom, 3)
                            .fixedSize()
                            .fontWeight(.bold)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            if let video = player.video {
                if let url = video.url {
                    ShareLink(item: url) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("shareVideo")

                    Button {
                        openBrowserUrl(.url(url.absoluteString))
                    } label: {
                        Image(systemName: Const.appBrowserSF)
                            .padding(5)
                    }
                    .accessibilityLabel("openInAppBrowser")
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .font(.headline)
        .fontWeight(.bold)
        .foregroundStyle(Color.automaticBlack.opacity(0.5))
        .padding(.vertical, 8)
        .background {
            Color.myBackgroundGray
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .padding(.horizontal)
        .environment(\.symbolVariants, .fill)
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
    }

    func toggleBookmark() {
        if let video = player.video {
            VideoService.toggleBookmark(video, modelContext)
            hapticToggle.toggle()
        }
    }
}

#Preview {
    VideoPlayerFooter(
        openBrowserUrl: { _ in },
        setShowMenu: { },
        sleepTimerVM: SleepTimerViewModel(),
        onSleepTimerEnded: { _ in })
        .modelContainer(DataController.previewContainer)
        .environment(NavigationManager.getDummy())
        .environment(PlayerManager.getDummy())
}
