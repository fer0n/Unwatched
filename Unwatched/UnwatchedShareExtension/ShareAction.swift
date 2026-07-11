//
//  ShareAction.swift
//  UnwatchedShareExtension
//

import SwiftUI
import UnwatchedShared

enum ShareLinkKind {
    case video
    case channel
}

enum ShareAction: CaseIterable {
    case play
    case queueNext
    case queueLast
    case addToInbox

    /// Reuses the existing localized catalog keys/icons from the browser's context menu
    /// (ContextMenuAction) so this matches the rest of the app.
    var title: LocalizedStringKey {
        switch self {
        case .play: return "play"
        case .queueNext: return "queueNext"
        case .queueLast: return "queueLast"
        case .addToInbox: return "addToInbox"
        }
    }

    var systemImage: String {
        switch self {
        case .play: return "play.fill"
        case .queueNext: return "text.insert"
        case .queueLast: return "text.append"
        case .addToInbox: return "tray.fill"
        }
    }

    static func actions(for kind: ShareLinkKind) -> [ShareAction] {
        switch kind {
        case .video: return [.play, .queueNext, .queueLast, .addToInbox]
        case .channel: return []
        }
    }

    /// This action's equivalent in the shared "remembered action" setting.
    var settingCase: ShareExtensionActionSetting {
        switch self {
        case .play: return .play
        case .queueNext: return .queueNext
        case .queueLast: return .queueLast
        case .addToInbox: return .addToInbox
        }
    }
}
