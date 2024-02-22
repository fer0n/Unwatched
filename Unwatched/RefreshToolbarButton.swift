//
//  RefreshToolbarButton.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct RefreshToolbarButton: ToolbarContent {
    @Environment(RefreshManager.self) var refresher
    var refreshOnlySubscription: PersistentIdentifier?
    @State var isLoading = false
    @State private var rotation = 0.0

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                if isLoading { return }
                if let subId = refreshOnlySubscription {
                    refresher.refreshSubscription(subscriptionId: subId)
                } else {
                    refresher.refreshAll()
                }
            } label: {
                Image(systemName: Const.refreshSF)
                    .font(.system(size: 13))
                    .rotationEffect(Angle(degrees: rotation))
            }
            .onAppear {
                // Workaround: if refresher.isLoading is set to true before the view appears, it doesn't animate
                guard isLoading != refresher.isLoading else {
                    return
                }
                withAnimation {
                    isLoading = refresher.isLoading
                }
            }
            .onChange(of: refresher.isLoading) {
                isLoading = refresher.isLoading
            }
            .onChange(of: isLoading) {
                if isLoading {
                    nextTurn()
                    refresher.isAnimating = true
                }
            }
            .modifier(AnimationCompletionCallback(animatedValue: rotation) {
                if isLoading {
                    nextTurn()
                } else {
                    refresher.isAnimating = false
                }
            })
        }
    }

    private func nextTurn() {
        withAnimation(.linear(duration: 1)) {
            rotation += 180
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
