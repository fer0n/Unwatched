//
//  AddSubscriptionView.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

struct AddSubscriptionView: View {
    @Environment(RefreshManager.self) var refresher
    @Environment(\.dismiss) var dismiss

    var subManager: SubscribeManager

    var body: some View {
        ScrollView {
            VStack {
                headerLogo
                    .padding()
                if let errorMessage = subManager.errorMessage {
                    Text(errorMessage)
                }
                SubStateOverview(subStates: subManager.newSubs,
                                 importSource: .urlImport)
                    .padding(.horizontal)

                Button("close") {
                    dismiss()
                }
                .padding()
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
        }
        .onDisappear {
            if subManager.newSubs != nil {
                Task {
                    await refresher.refreshAll()
                }
            }
        }
    }

    var headerLogo: some View {
        VStack(spacing: 0) {
            Image(systemName: Const.libraryTabSF)
                .resizable()
                .frame(width: 50, height: 50)
            Text("addSubscription")
                .font(.system(size: 20, weight: .heavy))
                .submitLabel(.done)
        }
    }
}

#Preview {
    AddSubscriptionView(subManager: SubscribeManager())
        .modelContainer(DataProvider.previewContainer)
}
