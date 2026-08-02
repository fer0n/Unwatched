//
//  InboxCardActionBar.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

/// Buttons underneath the inbox card stack, highlighting the action the current swipe aims at
struct InboxCardActionBar: View {
    let swipe: InboxCardSwipe
    let perform: (InboxCardAction) -> Void

    static let buttonSize: CGFloat = 52
    static let bottomPadding: CGFloat = 12
    static let topPadding: CGFloat = 5

    @ScaledMetric(wrappedValue: buttonSize) private var size: CGFloat

    var body: some View {
        let highlighted = swipe.highlighted

        return HStack(spacing: 0) {
            ForEach(InboxCardAction.allCases) { action in
                button(action, isHighlighted: highlighted == action)
                    .frame(maxWidth: 75)
            }
        }
        .contentShape(.rect)
    }

    private func button(_ action: InboxCardAction, isHighlighted: Bool) -> some View {
        let isDisabled = swipe.isDisabled(action)

        return Button {
            perform(action)
        } label: {
            Image(systemName: action.systemImage)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(isHighlighted ? Color.backgroundColor : Color.neutralAccentColor)
                .frame(width: size, height: size)
                .actionGlass(isHighlighted: isHighlighted)
                .scaleEffect(isHighlighted ? 1.15 : 1)
                .opacity(isDisabled ? 0.35 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(action.label)
        .animation(.bouncy(duration: 0.25), value: isHighlighted)
        .animation(.easeInOut(duration: 0.2), value: isDisabled)
    }
}

private extension View {
    @ViewBuilder
    func actionGlass(isHighlighted: Bool) -> some View {
        #if os(visionOS)
        background(
            isHighlighted
                ? AnyShapeStyle(Color.neutralAccentColor)
                : AnyShapeStyle(.ultraThinMaterial),
            in: .circle
        )
        #else
        glassEffect(
            isHighlighted
                ? .regular.tint(Color.neutralAccentColor).interactive()
                : .regular.interactive(),
            in: .circle
        )
        #endif
    }
}

#Preview {
    let swiping = InboxCardSwipe()
    swiping.setDrag("1", to: CGSize(width: 100, height: 0))

    return VStack(spacing: 30) {
        InboxCardActionBar(swipe: InboxCardSwipe(), perform: { _ in })
        InboxCardActionBar(swipe: swiping, perform: { _ in })
    }
    .padding()
    .background(Color.backgroundColor)
}
