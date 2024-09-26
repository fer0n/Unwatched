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
        .modelContainer(DataController.previewContainer)
}

// let newSubs = [
//    SubscriptionState(url: URL(string: "https://www.youtube.com/@TomScottGo")!),
//    SubscriptionState(
//        url: URL(string: "https://www.youtube.com/@TomScottGo")!,
//        title: "Gamertag VR",
//        userName: "GamertagVR",
//        success: true),
//    SubscriptionState(
//        url: URL(string: "https://www.youtube.com/@TomScottGo")!,
//        userName: "veritasium",
//        error: "The request cannot be completed because you have" +
//            " exceeded your <a href=\"/youtube/v3/getting-started#quota\">quota</a>"
//    ),
//    SubscriptionState(url: URL(string: "https://www.youtube.com/@TomScottGo")!),
//    SubscriptionState(url: URL(string: "https://www.youtube.com/@TomScottGo")!, userName: "TomScottGo")
// ]
