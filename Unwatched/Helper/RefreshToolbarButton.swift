//
//  RefreshToolbarButton.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct CoreRefreshButton: View {
    @Environment(RefreshManager.self) var refresher
    var refreshOnlySubscription: PersistentIdentifier?
    @State private var rotation = 0.0

    var body: some View {
        HStack {
            if refresher.isSyncingIcloud {
                Image(systemName: "icloud.fill")
                    .opacity(0.5)
                    .accessibilityLabel("syncing")
            }
            Button {
                Task { @MainActor in
                    await refresh()
                }
            } label: {
                Image(systemName: Const.refreshSF)
                    .rotationEffect(Angle(degrees: rotation))
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
            .disabled(refresher.isSyncingIcloud)
        }
        .font(.footnote)
        .fontWeight(.bold)
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
        ToolbarItem(placement: .topBarTrailing) {
            CoreRefreshButton(refreshOnlySubscription: refreshOnlySubscription)
        }
    }

}

// #Preview {
//     Image(systemName: Const.refreshSF)
//         .font(.system(size: 13))
//         .symbolEffect(.variableColor.iterative, options: .repeating, value: true)
//    RefreshToolbarButton()
//         .environment(RefreshManager())
// }
