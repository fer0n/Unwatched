//
//  AddSubscription.swift
//  Unwatched
//

import AppIntents
import SwiftData
import UnwatchedShared

struct AddSubscription: AppIntent {
    static var title: LocalizedStringResource { "addSubscription" }
    static let description = IntentDescription("addSubscriptionDescription")

    @Parameter(title: "youtubeChannelUrl")
    var youtubeUrl: URL

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String?> {
        Signal.log("Shortcut.AddSubscription")
        let subInfo = SubscriptionInfo(youtubeUrl)

        let result = try await SubscriptionService.addSubscriptions(subscriptionInfo: [subInfo])
        let sub = result.first
        return .result(value: sub?.title)
    }

    static var parameterSummary: some ParameterSummary {
        Summary("addSubscription \(\.$youtubeUrl)")
    }
}
