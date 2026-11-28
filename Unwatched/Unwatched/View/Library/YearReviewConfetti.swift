//
//  YearReviewConfetti.swift
//  Unwatched
//

import SwiftUI

struct YearReviewConfetti: View {
    let isActive: Bool
    let color: Color

    @State private var start: Date?

    private let duration: TimeInterval = 8
    private static let pieces = ConfettiPiece.make(count: 140)

    var body: some View {
        TimelineView(.animation(paused: start == nil)) { timeline in
            Canvas { context, size in
                guard let start else { return }
                let elapsed = timeline.date.timeIntervalSince(start)
                guard elapsed < duration else { return }
                let palette = [
                    Color.white,
                    color.mix(with: .white, by: 0.6),
                    color.mix(with: .white, by: 0.3),
                    color
                ]
                for piece in Self.pieces {
                    draw(piece, at: elapsed, in: &context, size: size, palette: palette)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task(id: isActive) {
            guard isActive else {
                await YearReviewReset.afterFade()
                start = nil
                return
            }
            try? await Task.sleep(for: .seconds(0.3))
            guard !Task.isCancelled else { return }
            start = .now
            try? await Task.sleep(for: .seconds(duration))
            if !Task.isCancelled { start = nil }
        }
    }

    private func draw(
        _ piece: ConfettiPiece,
        at elapsed: TimeInterval,
        in context: inout GraphicsContext,
        size: CGSize,
        palette: [Color]
    ) {
        let time = elapsed - piece.delay
        guard time > 0 else { return }
        let top = -20 + piece.speed * time + 40 * time * time
        guard top < size.height + 20 else { return }
        let left = piece.start * size.width + sin(time * piece.swayFrequency + piece.phase) * piece.sway
        var copy = context
        copy.translateBy(x: left, y: top)
        copy.rotate(by: .radians(piece.spin * time + piece.phase))
        copy.scaleBy(x: cos(time * piece.flip), y: 1)
        let rect = CGRect(x: -piece.size / 2, y: -piece.size * 0.3, width: piece.size, height: piece.size * 0.6)
        copy.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(palette[piece.colorIndex % palette.count]))
    }
}

struct ConfettiPiece {
    let start: Double
    let delay: Double
    let speed: Double
    let sway: Double
    let swayFrequency: Double
    let phase: Double
    let spin: Double
    let flip: Double
    let size: Double
    let colorIndex: Int

    static func make(count: Int) -> [ConfettiPiece] {
        (0..<count).map { _ in
            ConfettiPiece(
                start: .random(in: 0...1),
                delay: .random(in: 0...1.6),
                speed: .random(in: 90...190),
                sway: .random(in: 8...30),
                swayFrequency: .random(in: 1...3),
                phase: .random(in: 0...(2 * .pi)),
                spin: .random(in: -4...4),
                flip: .random(in: 3...8),
                size: .random(in: 7...13),
                colorIndex: .random(in: 0..<4)
            )
        }
    }
}
