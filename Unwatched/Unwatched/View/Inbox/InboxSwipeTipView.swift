//
//  InboxSwipeTipView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared
import TipKit

struct InboxSwipeTipView: View {
    @AppStorage(Const.themeColor) var theme = ThemeColor()

    var swipeTip = InboxSwipeTip()

    var body: some View {
        TipView(swipeTip)
            .tipBackground(Color.insetBackgroundColor)
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button(action: invalidateTip) {
                    Image(systemName: "text.insert")
                        .accessibilityLabel("queueNext")
                }
                .tint(theme.color.mix(with: Color.black, by: 0.1))

                Button(action: invalidateTip) {
                    Image(systemName: Const.queueBottomSF)
                }
                .accessibilityLabel("queueLast")
                .tint(theme.color.mix(with: Color.black, by: 0.3))
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(action: invalidateTip) {
                    Image(systemName: Const.clearSF)
                }
                .accessibilityLabel("clear")
                .tint(theme.color.mix(with: Color.black, by: 0.9))
            }
    }

    func invalidateTip() {
        swipeTip.invalidate(reason: .actionPerformed)
    }
}
