//
//  ChapterMiniControlView.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct ChapterMiniControlView: View {
    @Environment(PlayerManager.self) var player
    @Environment(NavigationManager.self) var navManager
    @State var triggerFeedback = false

    var setShowMenu: () -> Void
    var showInfo: Bool = true

    var body: some View {
        let hasChapters = player.currentChapter != nil
        let hasAnyChapters = player.video?.chapters?.isEmpty

        VStack(spacing: 20) {
            Grid(horizontalSpacing: 5, verticalSpacing: 0) {
                GridRow {
                    if hasChapters {
                        Button(action: goToPrevious) {
                            Image(systemName: Const.previousChapterSF)
                                .font(.system(size: 15))
                        }
                        .keyboardShortcut(.leftArrow)
                        .buttonStyle(ChangeChapterButtonStyle())
                        .disabled(player.previousChapter == nil)
                    } else {
                        Color.clear.fixedSize()
                    }

                    Button {
                        let val: ChapterDescriptionPage = (player.video?.chapters ?? []).isEmpty
                            ? .description
                            : .chapters
                        navManager.selectedDetailPage = val
                        navManager.showDescriptionDetail = true
                    } label: {
                        ZStack {
                            if let chapt = player.currentChapter {
                                Text(chapt.title)
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
                        ChapterMiniControlGoToNext(goToNext: goToNext)
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

            if showInfo, let video = player.video, !player.embeddingDisabled {
                videoDescription(video, hasChapters)
            }
        }
        .sensoryFeedback(Const.sensoryFeedback, trigger: triggerFeedback)
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .animation(.bouncy(duration: 0.5), value: player.currentChapter != nil)
        .onChange(of: hasAnyChapters) {
            if player.currentChapter == nil {
                player.handleChapterChange()
            }
        }
    }

    func openSubscription(_ sub: Subscription) {
        navManager.pushSubscription(sub)
        setShowMenu()
    }

    @ViewBuilder var title: some View {
        if let chapter = player.currentChapter {
            Text(chapter.title)
        } else {
            Text(player.video?.title ?? "")
                .font(.system(size: 20, weight: .heavy))
                .multilineTextAlignment(.center)
                .contextMenu(menuItems: {
                    if let url = player.video?.url {
                        ShareLink(item: url) {
                            HStack {
                                Image(systemName: "square.and.arrow.up.fill")
                                Text("share")
                            }
                        }
                    }
                })
        }
    }

    func videoDescription(_ video: Video, _ hasChapters: Bool) -> some View {
        Button {
            navManager.selectedDetailPage = .description
            navManager.showDescriptionDetail = true
        } label: {
            HStack {
                if let published = video.publishedDate {
                    Text(verbatim: "\(published.formatted)")
                    Text(Const.dotString)
                }
                if let duration = video.duration?.formattedSeconds {
                    Text(verbatim: "\(duration)")
                    Text(Const.dotString)
                }
                Image(systemName: Const.videoDescriptionSF)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.backgroundGray)
            .clipShape(.rect(cornerRadius: 10))
        }
    }

    func goToPrevious() {
        triggerFeedback.toggle()
        player.goToPreviousChapter()
    }

    func goToNext() {
        triggerFeedback.toggle()
        player.goToNextChapter()
    }
}

struct ChapterMiniControlRemainingText: View {
    @Environment(PlayerManager.self) var player

    var body: some View {
        if let remaining = player.currentRemainingText {
            Text(remaining)
                .foregroundStyle(Color.foregroundGray)
                .font(.system(size: 14))
                .lineLimit(1)
        }
    }
}

struct ChapterMiniControlGoToNext: View {
    @Environment(PlayerManager.self) var player

    var goToNext: () -> Void

    var body: some View {
        Button(action: goToNext) {
            Image(systemName: Const.nextChapterSF)
                .font(.system(size: 15))
        }
        .buttonStyle(ChangeChapterButtonStyle(
            chapter: player.currentChapter,
            remainingTime: player.currentRemaining
        ))
    }
}

#Preview {
    ChapterMiniControlView(setShowMenu: {})
        .modelContainer(DataController.previewContainer)
        .environment(PlayerManager.getDummy())
        .environment(NavigationManager.getDummy())
        .environment(Alerter())
}
