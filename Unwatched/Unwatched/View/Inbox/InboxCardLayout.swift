//
//  InboxCardLayout.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

extension InboxCard {
    /// A card's shape: thumbnail on top while the details fit underneath, beside them once they don't
    struct Layout: Equatable {
        let isHorizontal: Bool
        let size: CGSize
        let mediaSize: CGSize

        /// Two lines of title, one of info and the action bar
        static let baseDetailHeight: CGFloat = 155
        private static let maxStackedWidth: CGFloat = 600
        /// Keeps the details from ending up with a sliver of the card
        private static let maxMediaFraction: CGFloat = 0.5

        /// - Parameter minDetailHeight: `baseDetailHeight`, scaled for dynamic type by the caller
        init(available: CGSize, minDetailHeight: CGFloat) {
            let stackedWidth = min(available.width, Self.maxStackedWidth)
            let isHorizontal = available.height - stackedWidth / Const.defaultVideoAspectRatio < minDetailHeight
            let size = CGSize(
                width: isHorizontal ? available.width : stackedWidth,
                height: available.height
            )

            self.isHorizontal = isHorizontal
            self.size = size
            self.mediaSize = isHorizontal
                ? CGSize(
                    width: min(size.height * Const.defaultVideoAspectRatio,
                               size.width * Self.maxMediaFraction),
                    height: size.height
                )
                : CGSize(width: size.width, height: size.width / Const.defaultVideoAspectRatio)
        }

        var container: AnyLayout {
            isHorizontal
                ? AnyLayout(HStackLayout(alignment: .top, spacing: 0))
                : AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
        }

        /// Chips run off the card edge, never into the thumbnail
        var chapterBleedEdges: Edge.Set {
            isHorizontal ? .trailing : .horizontal
        }
    }
}
