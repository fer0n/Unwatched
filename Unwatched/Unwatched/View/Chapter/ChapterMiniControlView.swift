//
//  ChapterMiniControlView.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

struct ChapterMiniControlView: View {
    @Namespace var namespace

    @Environment(PlayerManager.self) var player
    @Environment(NavigationManager.self) var navManager
    @Environment(SheetPositionReader.self) var sheetPos

    @State var triggerFeedback = false

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
                    PreviousChapterButton { image in
                        image
                            .font(.system(size: 20))
                    }
                    .buttonStyle(ChangeChapterButtonStyle(size: chapterButtonSize))
                    .disabled(player.previousChapterDisabled)
                    .opacity(hasChapters ? 1 : 0)
                    .frame(maxWidth: hasChapters ? nil : 0)

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
                    .if(!Device.isIphone) {
                        $0.geometryGroup()
                    }

                    HStack(spacing: limitHeight ? 0 : -5) {
                        NextChapterButton { image in
                            image
                                .font(.system(size: 20))
                        }
                        .buttonStyle(ChangeChapterButtonStyle(
                            chapter: player.currentChapter,
                            size: chapterButtonSize
                        ))
                        .disabled(player.nextChapter == nil)

                        if inlineTime {
                            ChapterMiniControlRemainingText()
                                .matchedGeometryEffect(id: "remainingText", in: namespace)
                                .allowsHitTesting(false)
                        }
                    }
                    .accessibilityElement()
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("nextChapter")
                    .opacity(hasChapters ? 1 : 0)
                    .frame(maxWidth: hasChapters ? nil : 0)
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
                                .matchedGeometryEffect(id: "remainingText", in: namespace)
                                .allowsHitTesting(false)
                                .frame(height: 0)
                                .accessibilityHidden(true)
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
        player.setShowMenu()
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

    var chapterButtonSize: CGFloat {
        limitHeight ? 32 : 40
    }
}

struct ChapterMiniControlRemainingText: View {
    var body: some View {
        ChapterTimeRemaining()
            .font(.system(size: 12).monospacedDigit())
            .fontWidth(.condensed)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }
}

#Preview {
    ChapterMiniControlView(handleTitleTap: {})
        .modelContainer(DataProvider.previewContainer)
        .environment(PlayerManager.getDummy())
        .environment(NavigationManager.getDummy())
        .environment(Alerter())
}
