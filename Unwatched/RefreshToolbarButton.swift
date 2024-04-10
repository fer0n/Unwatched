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
            }
            Button {
                Task { @MainActor in
                    await refresh()
                }
            } label: {
                Image(systemName: Const.refreshSF)
                    .rotationEffect(Angle(degrees: rotation))
            }
            .contextMenu {
                Button {
                    Task { @MainActor in
                        await refresh(updateExisting: true)
                    }
                } label: {
                    Label("updateRefresh", systemImage: "arrow.up")
                }
            }
            .disabled(refresher.isSyncingIcloud)
        }
        .font(.system(size: 13))
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
    private func refresh(updateExisting: Bool = false) async {
        if refresher.isLoading { return }
        if let subId = refreshOnlySubscription {
            await refresher.refreshSubscription(subscriptionId: subId, updateExisting: updateExisting)
        } else {
            await refresher.refreshAll(updateExisting: updateExisting)
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
