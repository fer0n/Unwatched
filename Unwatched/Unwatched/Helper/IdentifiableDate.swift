//
//  IdentifiableDate.swift
//  Unwatched
//

import SwiftUI

struct IdentifiableDate {
    let date: Date?
    let id = UUID()

    init(_ date: Date?) {
        self.date = date
    }
}
