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
    @State var triggerFeedback = false

    var setShowMenu: () -> Void

    var body: some View {
        let hasChapters = player.currentChapter != nil
        let hasAnyChapters = player.video?.chapters?.isEmpty

        VStack(spacing: 20) {
            Grid(horizontalSpacing: 5, verticalSpacing: 0) {
                GridRow {
                    if hasChapters {
                        PreviousChapterButton { image in
                            image
                                .font(.system(size: 15))
                        }
                        .keyboardShortcut(.leftArrow)
                        .buttonStyle(ChangeChapterButtonStyle())
                        .disabled(player.previousChapterDisabled)
                    } else {
                        Color.clear.fixedSize()
                    }

                    Button {
                        let val: ChapterDescriptionPage = (player.video?.sortedChapters ?? []).isEmpty
                            ? .description
                            : .chapters
                        navManager.selectedDetailPage = val
                        navManager.showDescriptionDetail = true
                    } label: {
                        ZStack {
                            if let chapt = player.currentChapter {
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
                    }

                    if hasChapters {
                        NextChapterButton { image in
                            image
                                .font(.system(size: 15))
                        }
                        .buttonStyle(ChangeChapterButtonStyle(
                            chapter: player.currentChapter,
                            remainingTime: player.currentRemaining
                        ))
                        .keyboardShortcut(.rightArrow)
                        .disabled(player.nextChapter == nil)
                    } else {
                        Color.clear.fixedSize()
                    }
                }

                GridRow {
                    Color.clear.fixedSize()

                    InteractiveSubscriptionTitle(video: player.video,
                                                 subscription: player.video?.subscription,
                                                 openSubscription: openSubscription)

                    if hasChapters {
                        ChapterMiniControlRemainingText()
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
                .contextMenu(menuItems: {
                    if let url = player.video?.url {
                        ShareLink(item: url) {
                            Label("shareVideo", systemImage: "square.and.arrow.up.fill")
                        }
                    }
                })
        }
    }
}

struct BackgroundProgressBar: View {
    @Environment(PlayerManager.self) var player

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.backgroundGray

                if let elapsed = player.currentTime,
                   let total = player.video?.duration {
                    let width = (elapsed / total) * geometry.size.width

                    HStack(spacing: 0) {
                        Color.foregroundGray
                            .opacity(0.2)
                            .frame(width: width)
                            .animation(.default, value: width)
                        Color.clear
                    }
                }
            }
        }
    }
}

struct ChapterMiniControlRemainingText: View {
    @Environment(PlayerManager.self) var player

    var body: some View {
        if let remaining = player.currentRemainingText {
            Text(remaining)
                .font(.system(size: 14).monospacedDigit())
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
