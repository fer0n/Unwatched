//
//  InboxCardSwipe.swift
//  Unwatched
//

import SwiftUI

/// The swipe the front card of the inbox stack is under
///
/// Only `InboxCardTransform` and the action bar read it; in `InboxCardStack`'s own state a drag
/// would rebuild every card, re-reading its video from the store.
@Observable
@MainActor
final class InboxCardSwipe {
    var drag: Drag?

    var titleOpacity: Double = 1

    /// Skipping sends the card to the back of the stack; the last one has nowhere to go
    private(set) var isSkipDisabled = false

    /// The action the drag has come far enough for, stored rather than derived so the action bar
    /// only updates when it changes instead of on every frame of the drag
    private(set) var highlighted: InboxCardAction?

    /// How long a triggered action stays lit up, a flick can be over before its button ever showed
    private static let minHighlight: TimeInterval = 0.35

    private var highlightedAt: Date?
    private var unhighlight: Task<Void, Never>?

    struct Drag {
        let youtubeId: String
        let translation: CGSize
    }

    func translation(of youtubeId: String?) -> CGSize {
        guard let drag, drag.youtubeId == youtubeId else { return .zero }
        return drag.translation
    }

    /// An action the card can be dragged towards, but that won't be carried out
    func isDisabled(_ action: InboxCardAction) -> Bool {
        action == .skip && isSkipDisabled
    }

    func setSkipDisabled(_ disabled: Bool) {
        guard isSkipDisabled != disabled else { return }
        isSkipDisabled = disabled
    }

    func setDrag(_ youtubeId: String, to translation: CGSize) {
        unhighlight?.cancel()
        drag = .init(youtubeId: youtubeId, translation: translation)
        fadeTitle(to: Self.titleOpacity(draggedUp: -translation.height))
        // a disabled action never lights up its button, the swipe won't reach it
        let triggered = InboxCardAction.triggered(by: translation)
        highlight(triggered.flatMap { isDisabled($0) ? nil : $0 })
    }

    /// The card is on its way out, its button stays lit until it has been up for `minHighlight`
    func trigger(_ action: InboxCardAction) {
        unhighlight?.cancel()
        let shownFor = highlighted == action ? -(highlightedAt?.timeIntervalSinceNow ?? 0) : 0
        drag = nil
        highlight(action)

        let remaining = Self.minHighlight - shownFor
        guard remaining > 0 else {
            highlight(nil)
            return
        }
        unhighlight = Task {
            try? await Task.sleep(for: .seconds(remaining))
            guard !Task.isCancelled else { return }
            highlight(nil)
        }
    }

    func reset() {
        unhighlight?.cancel()
        drag = nil
        highlight(nil)
        fadeTitle(to: 1)
    }

    private func highlight(_ action: InboxCardAction?) {
        guard highlighted != action else { return }
        highlighted = action
        highlightedAt = action == nil ? nil : .now
    }

    /// `@Observable` invalidates on any write, even one that changes nothing: a sideways drag
    /// would otherwise re-render the navigation title on every frame of it
    private func fadeTitle(to opacity: Double) {
        guard titleOpacity != opacity else { return }
        titleOpacity = opacity
    }

    private static func titleOpacity(draggedUp: CGFloat) -> Double {
        let fadeDistance = InboxCardAction.triggerDistance / 2
        return 1 - min(1, max(0, Double(draggedUp) / Double(fadeDistance)))
    }
}
