//
//  SubscriptionStateView.swift
//  Unwatched
//

import Foundation
import SwiftUI
import UnwatchedShared

struct SubscriptionStateView: View {
    var state: SubscriptionState
    @Binding var showErrorDetailsFor: UUID?

    var body: some View {
        VStack {
            HStack {
                let color: Color = state.success || state.alreadyAdded ? .green : .red
                let systemName = state.success
                    ? Const.watchedSF
                    : state.alreadyAdded
                    ? Const.alreadyInLibrarySF
                    : Const.clearSF
                Image(systemName: systemName)
                    .resizable()
                    .frame(width: 25, height: 25)
                    .foregroundStyle(.white, color)
                    .symbolRenderingMode(.palette)
                Text(state.title ?? state.userName ?? state.url?.absoluteString ?? "-")
                    .font(.system(.headline))
                    .lineLimit(1)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .onTapGesture {
                withAnimation {
                    if showErrorDetailsFor == state.id {
                        showErrorDetailsFor = nil
                    } else {
                        showErrorDetailsFor = state.id
                    }
                }
            }
            if let error = state.error, showErrorDetailsFor == state.id {
                Text(error)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(nil)
                    .padding()
                    .cornerRadius(10)
                    .padding([.bottom])
            }
        }
    }
}
