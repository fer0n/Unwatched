//
//  QueueViewUnavailable.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct QueueViewUnavailable: View {
    @AppStorage(Const.themeColor) var theme = ThemeColor()
    @Environment(NavigationManager.self) private var navManager
    @AppStorage(Const.enableIcloudSync) private var enableIcloudSync = false
    @Environment(RefreshManager.self) private var refresher
    @State private var progress = SyncProgress()

    /// An empty tag looks like an empty queue, so the way out is offered here too.
    var isFiltered: Bool = false
    var tag: Tag?

    var body: some View {
        let isImporting = tracksSync && progress.isImporting(isSyncing: refresher.isSyncingIcloud)
        Group {
            if isImporting {
                importingContent
            } else {
                emptyContent
            }
        }
        .animation(.default, value: isImporting)
        .contentShape(Rectangle())
        .handleVideoUrlDrop(.queue)
        .task(id: tracksSync) {
            guard tracksSync else { return }
            await progress.track(in: DataProvider.shared.container)
        }
    }

    private var tracksSync: Bool {
        enableIcloudSync && !isFiltered && !SyncTotals.installHasCaughtUp
    }

    private var importingContent: some View {
        ContentUnavailableView {
            Label {
                Text("syncImportTitle")
            } icon: {
                SyncImportRing(share: progress.pendingShare(of: SyncTotals.published), color: theme.color)
            }
        } description: {
            Text("syncImportDescription")
        }
    }

    private var emptyContent: some View {
        ContentUnavailableView {
            Label {
                Text(isFiltered ? "noQueueItemsInTag" : "noQueueItems")
            } icon: {
                // different symbols have different intrinsic sizes at the same point size;
                // a fixed frame keeps the icon visually consistent across tags
                Image(systemName: tag?.displaySymbol ?? "rectangle.stack.badge.play.fill")
                    .font(.system(size: 56))
                    .frame(width: 56, height: 56)
                    .contentTransition(.symbolEffect(.replace))
            }
        } description: {
            Text(isFiltered ? "noQueueItemsInTagDescription" : "noQueueItemsDescription")
        } actions: {
            Group {
                if isFiltered {
                    Button {
                        withAnimation {
                            navManager.queueTag = .all
                        }
                    } label: {
                        Text("allVideos")
                            .padding(.horizontal, 8)
                    }
                } else {
                    Button {
                        navManager.focusSearch()
                        Signal.log("Onboarding.BrowseYoutube")
                    } label: {
                        Text("browser")
                            .padding(.horizontal, 8)
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .bold()
            .foregroundStyle(theme.readableContrastColor)
            .tint(theme.color)
        }
    }
}

/// Fills with the share of the library that has arrived; without known totals the icon pulses
struct SyncImportRing: View {
    let share: Double?
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 5)
            Circle()
                .trim(from: 0, to: share ?? 0)
                .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: "icloud.and.arrow.down")
                .font(.system(size: 26))
                .foregroundStyle(.secondary)
                .symbolEffect(.pulse, isActive: share == nil)
        }
        .frame(width: 64, height: 64)
        .accessibilityElement(children: .ignore)
        .accessibilityHidden(share == nil)
        .accessibilityValue(Text(share ?? 0, format: .percent.precision(.fractionLength(0))))
    }
}
