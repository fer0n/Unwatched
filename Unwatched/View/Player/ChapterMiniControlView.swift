//
//  ChapterMiniControlView.swift
//  Unwatched
//

import SwiftUI

struct ChapterMiniControlView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(PlayerManager.self) var player
    @Environment(NavigationManager.self) var navManager
    @State var subscribeManager = SubscribeManager()
    @State var triggerFeedback = false

    var setShowMenu: () -> Void
    var showInfo: Bool = true

    var body: some View {
        let hasChapters = player.currentChapter != nil

        VStack(spacing: 20) {
            Grid(horizontalSpacing: 5, verticalSpacing: 0) {
                GridRow {
                    if hasChapters {
                        Button(action: goToPrevious) {
                            Image(systemName: "backward.end.fill")
                                .font(.system(size: 25))
                        }
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
                            Image(systemName: "forward.end.fill")
                                .font(.system(size: 25))
                        }
                        .disabled(player.nextChapter == nil)
                    } else {
                        Color.clear.fixedSize()
                    }
                }

                GridRow {
                    Color.clear.fixedSize()

                    subscriptionTitle

                    if hasChapters, let remaining = player.currentRemaining {
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
    }

    var subscriptionTitle: some View {
        HStack {
            Text(player.video?.subscription?.title ?? "–")
            if let icon = subscribeManager.getSubscriptionSystemName(video: player.video) {
                Image(systemName: icon)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.pulse, options: .repeating, isActive: subscribeManager.isLoading)
            }
        }
        .padding(5)
        .foregroundStyle(.gray)
        .onTapGesture {
            if let sub = player.video?.subscription {
                navManager.pushSubscription(sub)
                setShowMenu()
            }
        }
        .contextMenu {
            let isSubscribed = subscribeManager.isSubscribed(video: player.video)
            Button {
                withAnimation {
                    subscribeManager.handleSubscription(
                        video: player.video,
                        container: modelContext.container)
                }
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
                    Text("\(published.formatted)")
                    Text("•")
                }
                if let duration = video.duration?.formattedSeconds {
                    Text("\(duration)")
                    Text("•")
                }
                Image(systemName: "quote.bubble.fill")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.backgroundGray)
            .clipShape(RoundedRectangle(cornerRadius: 10))
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
