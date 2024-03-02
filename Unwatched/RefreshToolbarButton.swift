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
        Button {
            Task { @MainActor in
                await refresh()
            }
        } label: {
            Image(systemName: Const.refreshSF)
                .font(.system(size: 13))
                .rotationEffect(Angle(degrees: rotation))
        }
        .task(id: refresher.isLoading) {
            if refresher.isLoading {
                nextTurn()
            }
        }
        .modifier(AnimationCompletionCallback(animatedValue: rotation) {
            if refresher.isLoading {
                nextTurn()
            }
        })
    }

    @MainActor
    private func refresh() async {
        if refresher.isLoading { return }
        if let subId = refreshOnlySubscription {
            await refresher.refreshSubscription(subscriptionId: subId)
        } else {
            await refresher.refreshAll()
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
