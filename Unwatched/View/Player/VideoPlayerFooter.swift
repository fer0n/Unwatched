//
//  VideoPlayerFooter.swift
//  Unwatched
//

import SwiftUI

struct VideoPlayerFooter: View {
    @Environment(\.modelContext) var modelContext
    @Environment(PlayerManager.self) var player
    @State var hapticToggle: Bool = false

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
                            : "bookmark")
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
                        Text("showMenu")
                            .font(.caption)
                            .textCase(.uppercase)
                            .padding(.bottom, 3)
                            .fixedSize()
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

                    Link(destination: url) {
                        Image(systemName: "safari")
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .font(.system(size: 20))
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
    VideoPlayerFooter(sleepTimerVM: SleepTimerViewModel(), onSleepTimerEnded: { _ in })
}
