//
//  SeekButton.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct CoreSeekButton<Content>: View where Content: View {
    @Environment(PlayerManager.self) var player
    @State private var hapticToggle = false

    private let contentImage: ((Image) -> Content)
    let forward: Bool

    init(
        forward: Bool,
        @ViewBuilder content: @escaping (Image) -> Content
    ) {
        self.forward = forward
        self.contentImage = content
    }

    var body: some View {
        let label = forward
            ? String(localized: "seekForward\(Int(player.userSeekSeconds))")
            : String(localized: "seekBackward\(Int(player.userSeekSeconds))")

        Button {
            _ = forward ? player.seekForward() : player.seekBackward()
            hapticToggle.toggle()
        } label: {
            contentImage(Image(systemName: seekSymbol))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
    }

    /// The numbered symbols only exist for a handful of values; any other seek length falls back to the plain arrow
    /// rather than to a number that isn't the one being seeked.
    private var seekSymbol: String {
        let base = forward ? "goforward" : "gobackward"
        let seconds = Int(player.userSeekSeconds)
        let available: Set<Int> = [5, 10, 15, 30, 45, 60, 75, 90]
        return available.contains(seconds) ? "\(base).\(seconds)" : base
    }
}

struct SeekButton: View {
    let forward: Bool
    var isSmall: Bool = false

    var body: some View {
        CoreSeekButton(forward: forward) { image in
            image
                .fontWeight(.medium)
                // the glyph isn't optically centered within the symbol's bounding box
                .offset(y: -0.7)
                .playerToggleModifier(isOn: false, isSmall: isSmall)
        }
        .geometryGroup()
    }
}

#Preview {
    HStack {
        SeekButton(forward: false)
        SeekButton(forward: true)
    }
    .modelContainer(DataProvider.previewContainer)
    .environment(PlayerManager())
}
