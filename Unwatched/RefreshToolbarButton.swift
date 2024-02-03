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

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                if let subId = refreshOnlySubscription {
                    refresher.refreshSubscription(subscriptionId: subId)
                } else {
                    refresher.refreshAll()
                }
            } label: {
                Image(systemName: Const.refreshSF)
                    .font(.system(size: 13))
                    .rotationEffect(isLoading ? .degrees(180) : .degrees(0))
                    .animation(
                        isLoading ? Animation.linear(duration: 1).repeatForever(autoreverses: false) :
                            .default, value: isLoading)
            }
            .onAppear {
                guard isLoading != refresher.isLoading else {
                    return
                }
                withAnimation {
                    isLoading = refresher.isLoading
                }
            }
            .onChange(of: refresher.isLoading) {
                withAnimation {
                    isLoading = refresher.isLoading
                }
            }
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
