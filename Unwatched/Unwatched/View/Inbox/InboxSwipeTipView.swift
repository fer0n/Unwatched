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
            .listRowTip()
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Group {
                    Button("queueNext", systemImage: Const.queueNextSF, action: invalidateTip)
                        .tint(theme.color.mix(with: Color.black, by: 0.1))
                    Button("queueLast", systemImage: Const.queueLastSF, action: invalidateTip)
                        .tint(theme.color.mix(with: Color.black, by: 0.3))
                }
                .labelStyle(.iconOnly)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button("clear", systemImage: Const.clearSF, action: invalidateTip)
                    .labelStyle(.iconOnly)
                    .tint(theme.color.mix(with: Color.black, by: 0.9))
            }
    }

    func invalidateTip() {
        swipeTip.invalidate(reason: .actionPerformed)
    }
}
