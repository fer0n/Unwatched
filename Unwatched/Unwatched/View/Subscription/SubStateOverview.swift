//
//  SubscriptionState.swift
//  Unwatched
//

import Foundation
import SwiftUI
import UnwatchedShared

struct SubStateOverview: View {
    enum ImportSource {
        case csvImport
        case urlImport
    }

    var subStates: [SubscriptionState]?
    @State var showErrorDetailsFor: UUID?
    var importSource: ImportSource

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
                    return lhs.title ?? "" < rhs.title ?? ""
                }
                if lhs.userName != rhs.userName {
                    return lhs.userName ?? "" < rhs.userName ?? ""
                }
                return lhs.url?.absoluteString ?? "" < rhs.url?.absoluteString ?? ""
            }

            let partitionIndex = states.partition { !($0.success || $0.alreadyAdded) }
            let successStates = Array(states[..<partitionIndex])
            let errorStates = Array(states[partitionIndex...])

            if !errorStates.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("errorImporting")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(getErrorMessage())
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Text("errorImportingTryBrowser")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                Spacer().frame(height: 40)
            }

            VStack {
                renderStates(errorStates)
            }
            .padding(.bottom)

            renderStates(successStates)
        }
    }

    func getErrorMessage() -> String {
        switch importSource {
        case .csvImport:
            String(localized: "errorImportingMessageCsv")
        case .urlImport:
            String(localized: "errorImportingMessageChannelUrl")
        }
    }
}

#Preview {
    SubStateOverview(subStates: [
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
    ], importSource: .urlImport)
}
