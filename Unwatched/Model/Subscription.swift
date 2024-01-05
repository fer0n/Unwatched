//
//  Subscription.swift
//  Unwatched
//

import Foundation
import SwiftData

@Model
final class Subscription: CustomStringConvertible {
    @Attribute(.unique) var link: URL
    var title: String
    var subscribedDate: Date
    var mostRecentVideoDate: Date?

    init(link: URL, title: String) {
        self.link = link
        self.title = title
        self.subscribedDate = .now
    }

    var description: String {
        return "\(title) (\(link))"
    }
}
