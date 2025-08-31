//
//  AppNotificationData.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct AppNotificationData {
    let title: LocalizedStringKey
    var error: Error?
    var icon: String?
    var isLoading: Bool = false
    var timeout: TimeInterval = 3.0
}

enum DefaultNotification {
    case addingVideo,
         addedVideo,
         loading,
         success,
         error(_ error: Error)

    var notification: AppNotificationData {
        switch self {
        case .addingVideo:
            return AppNotificationData(
                title: "addingVideo",
                isLoading: true,
                timeout: 0
            )
        case .addedVideo:
            return AppNotificationData(
                title: "addedVideo",
                icon: Const.checkmarkSF,
                timeout: 1
            )
        case .loading:
            return AppNotificationData(
                title: "loading",
                isLoading: true,
                timeout: 0
            )
        case .success:
            return AppNotificationData(
                title: "success",
                icon: Const.checkmarkSF,
                timeout: 1
            )
        case .error(let error):
            return AppNotificationData(
                title: "errorOccured",
                error: error,
                icon: Const.errorSF,
                timeout: 10
            )
        }
    }
}
