//
//  RefreshToolbarButton.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

struct CoreRefreshButton: View {
    @Environment(\.modelContext) var modelContext

    @Environment(RefreshManager.self) var refresher
    var refreshOnlySubscription: PersistentIdentifier?
    @State private var rotation = 0.0

    var body: some View {
        HStack {
            Image(systemName: "icloud.fill")
                .symbolEffect(.pulse, options: .speed(0.7).repeating)
                .accessibilityLabel("syncing")
                .opacity(refresher.isSyncingIcloud ? 0.5 : 0)
                .animation(.default, value: refresher.isSyncingIcloud)

            Button {
                try? modelContext.save()
                Task { @MainActor in
                    await refresh()
                }
            } label: {
                if #available(iOS 18, *) {
                    Image(systemName: Const.refreshSF)
                        .symbolEffect(.rotate,
                                      options: .speed(1.5),
                                      isActive: refresher.isLoading)
                } else {
                    Image(systemName: Const.refreshSF)
                        .rotationEffect(Angle(degrees: rotation))
                }
            }
            .accessibilityLabel("refresh")
            .contextMenu {
                Button {
                    Task { @MainActor in
                        await refresh(hardRefresh: true)
                    }
                } label: {
                    Label("hardReload", systemImage: "clock.arrow.2.circlepath")
                }
            }
        }
        .font(.footnote)
        .fontWeight(.bold)
        .if(!supportsIos18) { view in
            view
                .modifier(AnimationCompletionCallback(animatedValue: rotation) {
                    if refresher.isLoading {
                        nextTurn()
                    }
                })
                .onChange(of: refresher.isLoading) {
                    if refresher.isLoading {
                        nextTurn()
                    }
                }
        }
    }

    private var supportsIos18: Bool {
        if #available(iOS 18.0, *) {
            return true
        }
        return false
    }

    @MainActor
    private func refresh(hardRefresh: Bool = false) async {
        if refresher.isLoading { return }
        if let subId = refreshOnlySubscription {
            await refresher.refreshSubscription(subscriptionId: subId, hardRefresh: hardRefresh)
        } else {
            await refresher.refreshAll(hardRefresh: hardRefresh)
        }
    }

    private func nextTurn() {
        withAnimation(.linear(duration: 1)) {
            rotation += 180
        }
    }
}

struct RefreshToolbarButton: ToolbarContent {
    var refreshOnlySubscription: PersistentIdentifier?

    var body: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            #if os(iOS)
            CoreRefreshButton(refreshOnlySubscription: refreshOnlySubscription)
            #else
            CoreRefreshButton(refreshOnlySubscription: refreshOnlySubscription)
                .buttonStyle(.borderless)
            #endif
        }
    }
}

struct ToolbarSpacerWorkaround: ToolbarContent {
    var body: some ToolbarContent {
        ToolbarItem(placement: .secondaryAction) {
            #if os(macOS)
            Button("") {}
                .buttonStyle(.plain)
            #endif
        }
    }
}

// #Preview {
//    RefreshToolbarButton()
//         .environment(RefreshManager())
// }
