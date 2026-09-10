//
//  WatchTile.swift
//  UnwatchedWatch
//

import SwiftUI

extension View {
    /// A block on the speed page.
    func watchTile(isOn: Bool = false) -> some View {
        font(.body)
            .foregroundStyle(isOn ? Color.black : Color.primary)
            .frame(maxWidth: .infinity)
            .frame(height: WatchTile.height)
            .background(WatchTile.fill(isOn: isOn), in: .rect(cornerRadius: WatchTile.radius))
    }
}

enum WatchTile {
    static let height: CGFloat = 40
    static let radius: CGFloat = 10

    static func fill(isOn: Bool) -> Color {
        isOn ? .white : .gray.opacity(0.25)
    }
}
