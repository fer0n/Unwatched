//
//  CurrentChapterPopup.swift
//  Unwatched
//

import SwiftUI

struct CurrentChapterPopup: View {
    let isVisible: Bool
    let chapterTitle: String?
    let currentTime: String
    let anchor: CGPoint

    var body: some View {
        if let chapterTitle {
            Text(chapterTitle)
                .font(.caption2)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(
                    Capsule()
                        .fill(.regularMaterial)
                        .shadow(radius: 4)
                )
                .frame(maxWidth: 200)
                .opacity(isVisible ? 1 : 0)
                .position(x: anchor.x, y: anchor.y)
                .animation(.default, value: isVisible)
        }
    }
}
