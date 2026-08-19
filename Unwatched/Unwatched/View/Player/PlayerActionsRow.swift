//
//  PlayerActionsRow.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

/// Speed selection and the player's action buttons.
/// More menu entries fill up the available width, the remaining ones stay inside the menu.
struct PlayerActionsRow: View {
    /// Only fill up to roughly an iPhone 16 Pro's content width, wider screens keep the rest in the menu
    static let maxFillWidth: CGFloat = 370

    @AppStorage(Const.preferPlayerType) var preferPlayerType: Bool = false

    let maxSpacing: CGFloat
    let minSpacing: CGFloat
    let compactSize: Bool
    let showRotateButton: Bool
    var sleepTimerVM: SleepTimerViewModel
    @Binding var autoHideVM: AutoHideVM

    /// How many inline entries the layout currently shows; the rest stay in the menu.
    /// Driven by `OverflowRowLayout` so every button is built once instead of once per `ViewThatFits`
    /// variant, which is what made scrolling expensive on iPad/Mac.
    @State private var inlineCount = PlayerMenuItem.inlineItems(preferPlayerType: false).count
    @State private var reporter = InlineCountReporter()

    var body: some View {
        let items = PlayerMenuItem.inlineItems(preferPlayerType: preferPlayerType)

        OverflowRowLayout(
            minSpacing: minSpacing,
            maxSpacing: maxSpacing,
            reporter: reporter,
            inlineCount: $inlineCount
        ) {
            CombinedPlaybackSpeedSettingPlayer(
                spacing: minSpacing,
                showTemporarySpeed: compactSize,
                isTransparent: false
            )

            #if os(iOS)
            PipButton()
            AirPlayButton()
            #endif

            // all entries stay in the tree so the layout can measure them; the ones that don't fit
            // are placed off-screen (and clipped) and picked up by the menu below instead
            ForEach(Array(items.enumerated()), id: \.element) { index, item in
                PlayerMenuItemButton(item: item)
                    .layoutValue(key: InlineIndexKey.self, value: index)
            }

            if compactSize {
                DescriptionButton(show: $autoHideVM.showDescription)
            }

            PlayerMoreMenuButton(
                sleepTimerVM: sleepTimerVM,
                inlineItems: Array(items.prefix(inlineCount))
            ) { image in
                image
                    .playerToggleModifier(
                        isOn: sleepTimerVM.isOn,
                        isSmall: true
                    )
                    .fontWeight(.bold)
            }

            if showRotateButton {
                RotateOrientationButton()
            }
        }
        .clipped()
        // caps how wide the row may get; in compact layout the play buttons next to it limit it already
        .frame(maxWidth: compactSize ? nil : Self.maxFillWidth)
    }
}

/// Marks a subview as an optional inline entry. Entries are dropped highest-index first when the row
/// runs out of room, so the remaining ones stay a prefix of `PlayerMenuItem.inlineItems`.
private struct InlineIndexKey: LayoutValueKey {
    static let defaultValue: Int? = nil
}

/// Horizontal row that keeps as many inline entries as fit and reports the count back through
/// `inlineCount`. Unlike `ViewThatFits` it builds every subview exactly once, so the expensive
/// controls (speed setting, AirPlay/PiP) aren't reconstructed once per measured variant.
private struct OverflowRowLayout: Layout {
    var minSpacing: CGFloat
    var maxSpacing: CGFloat
    var reporter: InlineCountReporter
    @Binding var inlineCount: Int

    struct Resolved {
        var sizes: [CGSize]
        var dropped: Set<Int>
        var gap: CGFloat
        var size: CGSize
        var keptInline: Int
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        resolve(proposal, subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let resolved = resolve(proposal, subviews)

        var originX = bounds.minX
        var isFirst = true
        for index in subviews.indices {
            if resolved.dropped.contains(index) {
                // parked off-screen (and clipped away) so it stays measurable without showing
                subviews[index].place(
                    at: CGPoint(x: -100_000, y: bounds.midY),
                    anchor: .leading,
                    proposal: ProposedViewSize(resolved.sizes[index])
                )
                continue
            }
            if !isFirst { originX += resolved.gap }
            isFirst = false
            subviews[index].place(
                at: CGPoint(x: originX, y: bounds.midY),
                anchor: .leading,
                proposal: ProposedViewSize(width: resolved.sizes[index].width, height: bounds.height)
            )
            originX += resolved.sizes[index].width
        }

        reporter.report(width: bounds.width, count: resolved.keptInline) { value in
            if value != inlineCount {
                inlineCount = value
            }
        }
    }

    private func resolve(_ proposal: ProposedViewSize, _ subviews: Subviews) -> Resolved {
        let available = proposal.width ?? .infinity
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let height = sizes.map(\.height).max() ?? 0

        // optional entries ordered by their inline index; dropped from the end when space runs out
        let optional = subviews.indices
            .compactMap { index in subviews[index][InlineIndexKey.self].map { (index, $0) } }
            .sorted { $0.1 < $1.1 }

        var dropped = Set<Int>()
        func minWidth() -> CGFloat {
            let visible = subviews.indices.filter { !dropped.contains($0) }
            let content = visible.reduce(0) { $0 + sizes[$1].width }
            return content + CGFloat(max(0, visible.count - 1)) * minSpacing
        }

        var dropQueue = optional
        while minWidth() > available, let last = dropQueue.popLast() {
            dropped.insert(last.0)
        }

        let visible = subviews.indices.filter { !dropped.contains($0) }
        let content = visible.reduce(0) { $0 + sizes[$1].width }
        let gapCount = max(0, visible.count - 1)
        // grow the gaps to fill the available width, but never past `maxSpacing`
        let widthAtMaxSpacing = content + CGFloat(gapCount) * maxSpacing
        let target = min(available, widthAtMaxSpacing)
        let gap = gapCount > 0
            ? min(maxSpacing, max(minSpacing, (target - content) / CGFloat(gapCount)))
            : 0
        let width = content + CGFloat(gapCount) * gap

        return Resolved(
            sizes: sizes,
            dropped: dropped,
            gap: gap,
            size: CGSize(width: width, height: height),
            keptInline: optional.count - dropped.count
        )
    }
}

/// Carries the inline count out of `OverflowRowLayout` into the row's state, applying only the
/// widest placement of an update.
///
/// The row is laid out at more than one width per update: besides its real width it also gets placed
/// at its compressed width, where none of the optional entries fit. Feeding every placement back into
/// the view flipped the count between those two answers, and every flip triggered the next layout
/// pass — an endless loop, visible as a flickering more menu button (iPad landscape, where the two
/// answers differ). Only the widest placement describes what's on screen, so that one wins.
private final class InlineCountReporter {
    private var widestWidth: CGFloat = 0
    private var widestCount = 0
    private var sawNarrowerPlacement = false
    private var isScheduled = false

    func report(width: CGFloat, count: Int, apply: @escaping (Int) -> Void) {
        if width > widestWidth {
            sawNarrowerPlacement = sawNarrowerPlacement || widestWidth > 0
            widestWidth = width
            widestCount = count
        } else if width < widestWidth {
            sawNarrowerPlacement = true
        }
        schedule(apply)
    }

    /// Collects the placements of one update before applying, long enough to cover them all and
    /// short enough to stay unnoticeable.
    private func schedule(_ apply: @escaping (Int) -> Void) {
        guard !isScheduled else { return }
        isScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
            isScheduled = false
            guard widestWidth > 0 else {
                // nothing was laid out in this window: the layout has settled
                return
            }
            let count = widestCount
            // widths of two updates may have landed in the same window (while rotating, say), so
            // take another one to pick up the settled width
            let needsAnotherWindow = sawNarrowerPlacement
            widestWidth = 0
            sawNarrowerPlacement = false
            apply(count)
            if needsAnotherWindow {
                schedule(apply)
            }
        }
    }
}
