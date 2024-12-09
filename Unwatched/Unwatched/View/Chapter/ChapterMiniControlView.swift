//
//  ChapterMiniControlView.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

struct ChapterMiniControlView: View {
    @Environment(PlayerManager.self) var player
    @Environment(NavigationManager.self) var navManager
    @Environment(SheetPositionReader.self) var sheetPos

    @State var triggerFeedback = false

    var setShowMenu: () -> Void

    var body: some View {
        let hasChapters = player.currentChapter != nil
        let hasAnyChapters = player.video?.chapters?.isEmpty

        VStack(spacing: 10) {
            DescriptionMiniProgressBar()
                .frame(maxWidth: .infinity)

            Grid(horizontalSpacing: 5, verticalSpacing: 0) {
                GridRow {
                    if hasChapters {
                        PreviousChapterButton { image in
                            image
                                .font(.system(size: 20))
                        }
                        .buttonStyle(ChangeChapterButtonStyle())
                        .disabled(player.previousChapterDisabled)
                    } else {
                        Color.clear.fixedSize()
                    }

                    Button {
                        if player.isAnyCompactHeight || (sheetPos.playerContentViewHeight ?? .infinity) < 300 {
                            // open dedicated sheet when there's not enough space
                            navManager.videoDetail = player.video
                        } else {
                            navManager.handleVideoDetail(scrollToCurrentChapter: true)
                        }
                    } label: {
                        ZStack {
                            if let chapt = player.currentChapterPreview ?? player.currentChapter {
                                Text(chapt.titleTextForced)
                            } else {
                                title
                            }
                        }
                        .padding(.vertical, 2)
                        .font(.system(.title2))
                        .fontWeight(.black)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .animation(nil, value: UUID())
                        .sensoryFeedback(Const.sensoryFeedback, trigger: player.currentChapterPreview) { old, new in
                            old != nil && new != nil
                        }
                    }
                    .highPriorityGesture(LongPressGesture(minimumDuration: 0.3).onEnded { _ in
                        if let url = player.video?.url {
                            triggerFeedback.toggle()
                            navManager.openUrlInApp(.url(url.absoluteString))
                        }
                    })

                    if hasChapters {
                        NextChapterButton { image in
                            image
                                .font(.system(size: 20))
                        }
                        .buttonStyle(ChangeChapterButtonStyle(
                            chapter: player.currentChapter,
                            text: player.currentRemainingText
                        ))
                        .disabled(player.nextChapter == nil)
                    } else {
                        Color.clear.fixedSize()
                    }
                }

                GridRow {
                    Color.clear.fixedSize()
                    Color.clear.fixedSize().frame(maxWidth: .infinity)

                    if hasChapters {
                        ChapterMiniControlRemainingText()
                            .padding(.top, -10)
                    } else {
                        EmptyView()
                    }
                }
            }
            .frame(maxWidth: 600)
        }
        .sensoryFeedback(Const.sensoryFeedback, trigger: triggerFeedback)
        .frame(maxWidth: .infinity)
        .animation(.bouncy(duration: 0.5), value: player.currentChapter != nil)
        .onChange(of: hasAnyChapters) {
            if player.currentChapter == nil {
                player.handleChapterChange()
            }
        }
    }

    func openSubscription(_ sub: Subscription) {
        navManager.pushSubscription(subscription: sub)
        setShowMenu()
    }

    @ViewBuilder var title: some View {
        if let chapter = player.currentChapter {
            Text(chapter.titleTextForced)
        } else {
            Text(player.video?.title ?? "")
                .font(.title3)
                .multilineTextAlignment(.center)
        }
    }
}

struct ChapterMiniControlRemainingText: View {
    @Environment(PlayerManager.self) var player

    var body: some View {
        if let remaining = player.currentRemainingText {
            Text(remaining)
                .font(.system(size: 12).monospacedDigit())
                .animation(.default, value: player.currentRemainingText)
                .contentTransition(.numericText(countsDown: true))
                .foregroundStyle(Color.foregroundGray)
                .lineLimit(1)
        }
    }
}

#Preview {
    ChapterMiniControlView(setShowMenu: {})
        .modelContainer(DataProvider.previewContainer)
        .environment(PlayerManager.getDummy())
        .environment(NavigationManager.getDummy())
        .environment(Alerter())
}
