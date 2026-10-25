//
//  SafariWebExtensionHandler.swift
//  UnwatchedSafariExtension
//

import SafariServices
import OSLog

private let logger = Logger(
    subsystem: "com.pentlandFirth.Unwatched.UnwatchedSafariExtension",
    category: "SafariExtension"
)

class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {

    func beginRequest(with context: NSExtensionContext) {
        let request = context.inputItems.first as? NSExtensionItem

        let profile: UUID? = request?.userInfo?[SFExtensionProfileKey] as? UUID

        let message: Any? = request?.userInfo?[SFExtensionMessageKey]

        let messageText = String(describing: message)
        let profileText = profile?.uuidString ?? "none"
        logger.log(
            "Received native message: \(messageText, privacy: .public) (profile: \(profileText, privacy: .public))"
        )

        let response = NSExtensionItem()

        response.userInfo = [ SFExtensionMessageKey: [ "echo": message ] ]

        context.completeRequest(returningItems: [ response ], completionHandler: nil)
    }
}
