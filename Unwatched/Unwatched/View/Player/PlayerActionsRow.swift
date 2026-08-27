//
//  PlayerActionsRow.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

/// Speed selection and the player's action buttons.
struct PlayerActionsRow: View {
    @AppStorage(Const.preferPlayerType) var preferPlayerType: Bool = false
    @Environment(PlayerManager.self) var player

    let maxSpacing: CGFloat
    let minSpacing: CGFloat
    let compactSize: Bool
    let showRotateButton: Bool
    var sleepTimerVM: SleepTimerViewModel
    @Binding var autoHideVM: AutoHideVM

    var body: some View {
        EvenlySpacedRowLayout(maxSpacing: maxSpacing) {
            CombinedPlaybackSpeedSettingPlayer(
                spacing: minSpacing,
                showTemporarySpeed: compactSize,
                isTransparent: false
            )

            WatchedButton(isSmall: true)

            if player.isAudioOnly {
                TrimSilenceButton()
            } else {
                PipButton()
            }

            if preferPlayerType {
                playerTypeButton
            } else {
                #if os(iOS)
                AirPlayButton()
                #endif
            }

            if compactSize {
                DescriptionButton(show: $autoHideVM.showDescription)
            }

            PlayerMoreMenuButton(sleepTimerVM: sleepTimerVM) { image in
                image
                    .playerToggleModifier(
                        isOn: sleepTimerVM.isOn,
                        isSmall: true
                    )
                    .fontWeight(.bold)
            }

            NextVideoButton(isSmall: true)

            if showRotateButton {
                RotateOrientationButton()
            }
        }
        .clipped()
        // in compact layout the play buttons next to it limit the width already
        .frame(maxWidth: compactSize ? nil : Const.playerRowMaxWidth)
    }

    private var playerTypeButton: some View {
        PlayerTypeButton { image in
            image.playerToggleModifier(isOn: false, isSmall: true)
        }
    }
}

/// Horizontal row that grows the gaps between its entries to fill the available width, capped at
/// `maxSpacing`. The gaps close before anything gets clipped.
private struct EvenlySpacedRowLayout: Layout {
    var maxSpacing: CGFloat

    func makeCache(subviews: Subviews) -> [CGSize] {
        subviews.map { $0.sizeThatFits(.unspecified) }
    }

    func updateCache(_ cache: inout [CGSize], subviews: Subviews) {
        cache = makeCache(subviews: subviews)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout [CGSize]) -> CGSize {
        let sizes = cache
        let gap = gap(for: proposal, sizes)
        return CGSize(
            width: sizes.reduce(0) { $0 + $1.width } + CGFloat(max(0, sizes.count - 1)) * gap,
            height: sizes.map(\.height).max() ?? 0
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout [CGSize]) {
        let gap = gap(for: proposal, cache)

        var originX = bounds.minX
        for (index, size) in cache.enumerated() {
            if index > 0 { originX += gap }
            subviews[index].place(
                at: CGPoint(x: originX, y: bounds.midY),
                anchor: .leading,
                proposal: ProposedViewSize(width: size.width, height: bounds.height)
            )
            originX += size.width
        }
    }

    private func gap(for proposal: ProposedViewSize, _ sizes: [CGSize]) -> CGFloat {
        let gapCount = max(0, sizes.count - 1)
        guard gapCount > 0 else { return 0 }
        let content = sizes.reduce(0) { $0 + $1.width }
        let spare = (proposal.width ?? .infinity) - content
        return min(maxSpacing, max(0, spare / CGFloat(gapCount)))
    }
}
