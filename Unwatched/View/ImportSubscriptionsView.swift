//
//  SubscriptionState.swift
//  Unwatched
//

import Foundation
import SwiftUI

struct ImportSubscriptionsView: View {
    var subStates: [SubscriptionState]?
    @State var showErrorDetailsFor: UUID?

    func renderStates(_ states: [SubscriptionState]) -> some View {
        ForEach(states) { state in
            SubscriptionStateView(state: state, showErrorDetailsFor: $showErrorDetailsFor)
        }
    }

    var body: some View {
        if let subState = subStates {
            // sort by success, then title, then userName, then url
            var states = subState.sorted { lhs, rhs in
                if lhs.success != rhs.success {
                    return lhs.success
                }
                if lhs.title != rhs.title {
                    return lhs.title ?? "" > rhs.title ?? ""
                }
                if lhs.userName != rhs.userName {
                    return lhs.userName ?? "" > rhs.userName ?? ""
                }
                return lhs.url.absoluteString > rhs.url.absoluteString
            }

            let partitionIndex = states.partition { !($0.success || $0.alreadyAdded) }
            let successStates = Array(states[..<partitionIndex])
            let errorStates = Array(states[partitionIndex...])

            VStack {
                renderStates(successStates)
            }
            .padding(.bottom)

            renderStates(errorStates)
        }
    }
}

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
                Text(state.title ?? state.userName ?? state.url.absoluteString)
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
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding([.bottom])
            }
        }
    }
}

#Preview {
    ImportSubscriptionsView(subStates: [
        SubscriptionState(url: URL(string: "https://www.youtube.com/@TomScottGo")!),
        SubscriptionState(
            url: URL(string: "https://www.youtube.com/@TomScottGo")!,
            title: "Gamertag VR",
            userName: "GamertagVR",
            success: true),
        SubscriptionState(
            url: URL(string: "https://www.youtube.com/@TomScottGo")!,
            title: "Gamertag VR",
            error: "Subscription already exists", alreadyAdded: true),
        SubscriptionState(
            url: URL(string: "https://www.youtube.com/@TomScottGo")!,
            title: "Gamertag VR",
            userName: "GamertagVR",
            success: true),
        SubscriptionState(
            url: URL(string: "https://www.youtube.com/@TomScottGo")!,
            userName: "veritasium",
            error: "The request cannot be completed because you have exceeded" +
                " your <a href=\"/youtube/v3/getting-started#quota\">quota</a>"
        ),
        SubscriptionState(url: URL(string: "https://www.youtube.com/@TomScottGo")!),
        SubscriptionState(url: URL(string: "https://www.youtube.com/@TomScottGo")!, userName: "TomScottGo")
    ])
}
