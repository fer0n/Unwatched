//
//  ChapterMiniControlView.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct ChapterMiniControlView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(PlayerManager.self) var player
    @Environment(NavigationManager.self) var navManager
    @State var subscribeManager = SubscribeManager()
    @State var triggerFeedback = false

    @State var videoIdToSubscribeTo: PersistentIdentifier?

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
                        .fontWeight(.bold)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                    }

                    if hasChapters {
                        Button(action: goToNext) {
                            Image(systemName: Const.nextChapterSF)
                                .font(.system(size: 15))
                        }
                        .buttonStyle(ChangeChapterButtonStyle(
                            chapter: player.currentChapter,
                            remainingTime: player.currentRemaining
                        ))
                        .disabled(player.nextChapter == nil)
                    } else {
                        Color.clear.fixedSize()
                    }
                }

                GridRow {
                    Color.clear.fixedSize()

                    if let sub = player.video?.subscription {
                        subscriptionTitle(sub: sub)
                    }

                    if hasChapters, let remaining = player.currentRemainingText {
                        Text(remaining)
                            .foregroundStyle(Color.foregroundGray)
                            .font(.system(size: 14))
                            .lineLimit(1)
                    } else {
                        EmptyView()
                    }
                }
            }
            if showInfo, let video = player.video, !player.embeddingDisabled {
                videoDescription(video, hasChapters)
            }
        }
        .sensoryFeedback(Const.sensoryFeedback, trigger: triggerFeedback)
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .padding(.vertical, 10)
        .animation(.bouncy(duration: 0.5), value: player.currentChapter != nil)
        .onChange(of: hasAnyChapters) {
            if player.currentChapter == nil {
                player.handleChapterChange()
            }
        }
        .onAppear {
            subscribeManager.container = modelContext.container
        }
        .task(id: videoIdToSubscribeTo) {
            if let videoId = videoIdToSubscribeTo {
                await subscribeManager.handleSubscription(videoId)
            }
        }
    }

    func subscriptionTitle(sub: Subscription) -> some View {
        Button {
            navManager.pushSubscription(sub)
            setShowMenu()
        } label: {
            HStack {
                Text(sub.displayTitle)
                if let icon = subscribeManager.getSubscriptionSystemName(video: player.video) {
                    Image(systemName: icon)
                        .contentTransition(.symbolEffect(.replace))
                        .symbolEffect(.pulse, options: .repeating, isActive: subscribeManager.isLoading)
                }
            }
            .padding(5)
            .foregroundStyle(.secondary)
        }
        .contextMenu {
            let isSubscribed = subscribeManager.isSubscribed(video: player.video)
            Button {
                videoIdToSubscribeTo = player.video?.persistentModelID
            } label: {
                HStack {
                    if isSubscribed {
                        Image(systemName: "xmark")
                        Text("unsubscribe")
                    } else {
                        Image(systemName: "plus")
                        Text("subscribe")
                    }
                }
            }
            .disabled(subscribeManager.isLoading)
            if let sub = player.video?.subscription {
                AspectRatioPicker(subscription: sub)
            }
        }
    }

    var title: some View {
        ZStack {
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

#Preview {
    ChapterMiniControlView(setShowMenu: {})
        .modelContainer(DataController.previewContainer)
        .environment(PlayerManager.getDummy())
        .environment(NavigationManager.getDummy())
        .environment(Alerter())
}
