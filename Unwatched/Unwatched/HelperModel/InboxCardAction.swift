//
//  InboxCardAction.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

/// What the topmost card of the inbox card stack can be swiped or tapped into.
/// The case order is the order the buttons are shown in.
enum InboxCardAction: String, Identifiable, CaseIterable {
    case queueNext
    case queueLast
    case skip
    case clear

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .queueNext: Const.queueNextSF
        case .queueLast: Const.queueLastSF
        case .skip: "arrow.turn.down.right"
        case .clear: Const.clearNoFillSF
        }
    }

    var label: LocalizedStringKey {
        switch self {
        case .queueNext: "queueNext"
        case .queueLast: "queueLast"
        case .skip: "skipVideo"
        case .clear: "clearVideo"
        }
    }

    /// Shared with the video list actions, see `Signal.videoAction`
    var analyticsAction: String {
        switch self {
        case .queueNext: "queueTop"
        case .queueLast: "queueBottom"
        case .skip: "skip"
        case .clear: "clear"
        }
    }

    /// Where the card is thrown when the action is triggered by its button
    var direction: CGSize {
        switch self {
        case .queueNext: CGSize(width: 1, height: 0)
        case .queueLast: CGSize(width: 0, height: 1)
        case .skip: CGSize(width: 0, height: -1)
        case .clear: CGSize(width: -1, height: 0)
        }
    }

    /// The action a drag is aiming at, `nil` while it's still too short to show one
    init?(translation: CGSize) {
        guard translation.length > Self.minimumDistance else { return nil }

        // 0° points right, 90° points down
        let angle = atan2(translation.height, translation.width) * 180 / .pi
        switch angle {
        case -45..<45:
            self = .queueNext
        case 45..<135:
            self = .queueLast
        case -135..<(-45):
            self = .skip
        default:
            self = .clear
        }
    }

    static let minimumDistance: CGFloat = 20
    static let triggerDistance: CGFloat = 60
    static let flickDistance: CGFloat = 250

    static func triggered(by translation: CGSize) -> InboxCardAction? {
        translation.length > triggerDistance ? InboxCardAction(translation: translation) : nil
    }

    /// How far a drag has come towards triggering its action, 0 while it's still too short for one
    static func progress(of translation: CGSize) -> CGFloat {
        let distance = translation.length - minimumDistance
        return min(1, max(0, distance / (triggerDistance - minimumDistance)))
    }
}
