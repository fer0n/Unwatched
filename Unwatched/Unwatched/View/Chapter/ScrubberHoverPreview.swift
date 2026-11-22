//
//  ScrubberHoverPreview.swift
//  Unwatched
//

#if os(macOS)
import SwiftUI
import UnwatchedShared

/// Shared so the card can draw outside the tab view that clips the scrubber.
@Observable @MainActor
final class ScrubberHoverState {
    static let shared = ScrubberHoverState()

    /// Pointer x within the track, nil when not hovering.
    var location: CGFloat?
    /// The hovered track in global coordinates.
    var trackFrame: CGRect = .zero
}

/// Hover and scrub preview card, drawn over the whole player.
struct ScrubberHoverPreview: View {
    @Environment(PlayerManager.self) private var player
    @State private var hostFrame: CGRect = .zero
    @State private var chapters: [SendableChapter] = []

    private static let thumbnailWidth: CGFloat = 160
    private static let thumbnailInset: CGFloat = 3
    private var hover: ScrubberHoverState { .shared }
    private var provider: ScrubberThumbnailProvider { .shared }

    var body: some View {
        let duration = player.video?.duration ?? 0
        let fraction = duration > 0 ? previewFraction(duration: duration) : nil
        let track = hover.trackFrame.offsetBy(dx: -hostFrame.minX, dy: -hostFrame.minY)

        HoverCardLayout(track: track, centerX: track.minX + (fraction ?? 0) * track.width) {
            if let fraction {
                card(time: Double(fraction) * duration, duration: duration)
                    .transition(.opacity)
            }
        }
        .allowsHitTesting(false)
        .animation(.easeOut(duration: 0.12), value: fraction == nil)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { hostFrame = $0 }
        // refreshed while hidden, so the title is there on the card's first frame
        .onChange(of: fraction == nil, initial: true) { _, hidden in
            if hidden { refreshChapters() }
        }
        .onChange(of: player.video?.youtubeId) { refreshChapters() }
    }

    private func refreshChapters() {
        chapters = player.video?.sortedChapterData ?? []
    }

    private func previewFraction(duration: Double) -> CGFloat? {
        if provider.isScrubbing {
            return provider.previewTime.map { CGFloat(min(max($0 / duration, 0), 1)) }
        }
        let width = hover.trackFrame.width
        guard width > 0, let location = hover.location else { return nil }
        return min(max(location / width, 0), 1)
    }

    private func card(time: Double, duration: Double) -> some View {
        let thumbnailSize = provider.spec?.preferredLevel.map {
            CGSize(
                width: Self.thumbnailWidth,
                height: Self.thumbnailWidth * CGFloat($0.thumbHeight) / CGFloat($0.thumbWidth)
            )
        }
        let chapterTitle = chapters.last { $0.startTime <= time }?.title

        return GlassEffectContainer(spacing: 0) {
            VStack(spacing: 6) {
                if let thumbnailSize {
                    ScrubberThumbnailView(provider: provider, time: time, duration: duration)
                        .frame(width: thumbnailSize.width, height: thumbnailSize.height)
                        .background(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .padding(Self.thumbnailInset)
                        .glassEffect(in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                }

                HStack(spacing: 6) {
                    if let chapterTitle {
                        Text(chapterTitle)
                            .lineLimit(1)
                    }
                    Text(time.formattedSecondsColon)
                        .monospacedDigit()
                        .foregroundStyle(chapterTitle == nil ? .primary : .secondary)
                        .fixedSize()
                }
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .glassEffect(in: Capsule())
                .frame(maxWidth: (thumbnailSize?.width ?? Self.thumbnailWidth) + 2 * Self.thumbnailInset)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Places the card above `track`, centered on `centerX` but kept within the track's ends.
private struct HoverCardLayout: Layout {
    let track: CGRect
    let centerX: CGFloat
    var gap: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let cardProposal = ProposedViewSize(width: max(track.width, 1), height: nil)
        for card in subviews {
            let size = card.sizeThatFits(cardProposal)
            let originX = size.width < track.width
                ? min(max(centerX - size.width / 2, track.minX), track.maxX - size.width)
                : track.midX - size.width / 2
            card.place(
                at: CGPoint(x: bounds.minX + originX, y: bounds.minY + track.minY - gap - size.height),
                anchor: .topLeading,
                proposal: cardProposal
            )
        }
    }
}

/// Feeds `ScrubberHoverState` from the pointer over the track. Pads by the hit slop itself so
/// the published frame is the bar, not the hit area.
struct ScrubberHoverTracking: ViewModifier {
    let enabled: Bool
    let hitSlop: CGFloat

    @State private var trackFrame: CGRect = .zero
    @State private var isHovered = false
    @State private var pendingLocation: CGFloat = 0
    @State private var revealTask: Task<Void, Never>?

    private static let revealDelay: Duration = .milliseconds(200)
    private var hover: ScrubberHoverState { .shared }

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                trackFrame = frame
                if isHovered { hover.trackFrame = frame }
            }
            .padding(.vertical, hitSlop)
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                guard enabled else { return }
                switch phase {
                case .active(let location):
                    hovered(at: location.x)
                case .ended:
                    endHover()
                }
            }
            .onChange(of: enabled) { _, enabled in
                if !enabled { endHover() }
            }
            .onDisappear(perform: endHover)
    }

    private func hovered(at location: CGFloat) {
        if !isHovered {
            isHovered = true
            hover.trackFrame = trackFrame
        }
        if hover.location != nil {
            hover.location = location
            return
        }
        pendingLocation = location
        guard revealTask == nil else { return }
        revealTask = Task {
            try? await Task.sleep(for: Self.revealDelay)
            guard !Task.isCancelled else { return }
            hover.location = pendingLocation
            revealTask = nil
        }
    }

    private func endHover() {
        revealTask?.cancel()
        revealTask = nil
        guard isHovered else { return }
        isHovered = false
        hover.location = nil
    }
}
#endif
