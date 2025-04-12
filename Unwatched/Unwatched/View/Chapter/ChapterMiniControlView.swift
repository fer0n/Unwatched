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
    var handleTitleTap: () -> Void
    var limitHeight = false
    var inlineTime = false

    var body: some View {
        let hasChapters = player.currentChapter != nil
        let hasAnyChapters = player.video?.chapters?.isEmpty

        VStack(spacing: limitHeight ? 0 : 10) {
            DescriptionMiniProgressBar(
                limitHeight: limitHeight,
                inlineTime: inlineTime
            )
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

                    let link = player.currentChapter?.link
                    HStack(spacing: 5) {
                        Button {
                            handleTitleTap()
                        } label: {
                            ZStack {
                                if let chapt = player.currentChapterPreview ?? player.currentChapter {
                                    Text(chapt.titleTextForced)
                                } else {
                                    title
                                        .padding(.vertical, 5)
                                }
                            }
                            .padding(.vertical, 2)
                            .font(.system(.title2))
                            .fontWeight(.black)
                            .lineLimit(1)
                            .frame(maxWidth: link == nil ? .infinity : nil)
                            .animation(nil, value: UUID())
                            .sensoryFeedback(Const.sensoryFeedback, trigger: player.currentChapterPreview) { old, new in
                                old != nil && new != nil
                            }
                        }
                        .buttonStyle(.plain)
                        .highPriorityGesture(LongPressGesture(minimumDuration: 0.3).onEnded { _ in
                            if let url = player.video?.url {
                                triggerFeedback.toggle()
                                navManager.openUrlInApp(.url(url.absoluteString))
                            }
                        })

                        if let link {
                            Link(destination: link, label: {
                                Image(systemName: "link.circle.fill")
                                    .font(.system(.title))
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(
                                        Color.automaticBlack,
                                        Color.backgroundColor
                                    )
                            })
                        }
                    }
                    .frame(maxWidth: link == nil ? nil : .infinity)

                    if hasChapters {
                        HStack(spacing: -5) {
                            NextChapterButton { image in
                                image
                                    .font(.system(size: 20))
                            }
                            .buttonStyle(ChangeChapterButtonStyle(
                                chapter: player.currentChapter
                            ))
                            .disabled(player.nextChapter == nil)

                            if inlineTime {
                                ChapterMiniControlRemainingText()
                                    .allowsHitTesting(false)
                            }
                        }
                    } else {
                        Color.clear.fixedSize()
                    }
                }

                if !inlineTime {
                    GridRow {
                        Color.clear
                            .fixedSize()
                            .frame(height: 0)

                        Color.clear
                            .fixedSize()
                            .frame(maxWidth: .infinity)
                            .frame(height: 0)

                        if hasChapters {
                            ChapterMiniControlRemainingText()
                                .allowsHitTesting(false)
                                .frame(height: 0)
                        } else {
                            EmptyView()
                        }
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
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

#Preview {
    ChapterMiniControlView(setShowMenu: {}, handleTitleTap: {})
        .modelContainer(DataProvider.previewContainer)
        .environment(PlayerManager.getDummy())
        .environment(NavigationManager.getDummy())
        .environment(Alerter())
}
