//
//  AppNotificationData.swift
//  Unwatched
//

import SwiftUI

struct AppNotificationData {
    let title: LocalizedStringKey
    var error: Error?
    var icon: String?
    var isLoading: Bool = false
    var timeout: TimeInterval = 3.0
}
