//
//  RefreshableEmptyDropView.swift
//  Unwatched
//

import SwiftUI

struct RefreshableEmptyDropView: View {
    var onRefresh: () async -> Void
    var onDrop: (_ items: [URL], _ location: CGPoint) -> Void

    var body: some View {
        GeometryReader { geo in
            ScrollView(.vertical) {
                Color.white.opacity(Double.leastNormalMagnitude)
                    .frame(
                        minWidth: geo.size.width,
                        minHeight: geo.size.height - 100
                    )
                    .contentShape(Rectangle())
                    .dropDestination(for: URL.self) { items, location in
                        onDrop(items, location)
                        return true
                    }
            }
        }
        .refreshable {
            await onRefresh()
        }
    }
}

// #Preview {
//    RefreshableEmptyDropView()
// }
