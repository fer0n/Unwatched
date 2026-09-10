//
//  WatchPlayerControls.swift
//  UnwatchedWatch
//

import SwiftUI
import UnwatchedShared

/// The three controls worth having on a wrist, with the timeline around the middle one.
struct WatchPlayerControls: View {
    let display: WatchPlayerDisplay
    let perform: (WatchPlayerAction) -> Void

    var body: some View {
        HStack(spacing: 10) {
            seekButton(forward: false)

            playButton

            seekButton(forward: true)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
    }

    private var playButton: some View {
        Button {
            perform(.togglePlay)
        } label: {
            Image(systemName: display.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                .resizable()
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .black)
                .fontWeight(.black)
                .frame(width: Self.playSize, height: Self.playSize)
                // On the image rather than the tap: `isPlaying` also turns over on its own.
                .contentTransition(.symbolEffect(.replace))
                .animation(.default, value: display.isPlaying)
                .symbolEffect(.pulse, isActive: display.isLoading)
        }
        .buttonStyle(.plain)
        .disabled(display.isLoading)
        .frame(width: Self.playSize, height: Self.playSize)
        .overlay {
            progressRing
        }
    }

    /// Inset by half its width so it sits *on* the glass edge and reads as the button's border.
    private var progressRing: some View {
        Circle()
            .inset(by: Self.ringWidth / 2)
            .stroke(.white.opacity(0.3), lineWidth: Self.ringWidth)
            .overlay {
                Circle()
                    .inset(by: Self.ringWidth / 2)
                    .trim(from: 0, to: display.fraction)
                    .stroke(.white, style: StrokeStyle(lineWidth: Self.ringWidth, lineCap: .round))
                    // Trims start at three o'clock; the top is where a clock face starts.
                    .rotationEffect(.degrees(-90))
            }
            .allowsHitTesting(false)
    }

    private func seekButton(forward: Bool) -> some View {
        let seconds = forward ? display.seek.forward : -display.seek.back
        return Button {
            perform(.seek(seconds))
        } label: {
            Image(systemName: WatchSeek.symbol(forward: forward, seconds: abs(seconds)))
                .font(.body)
        }
        .frame(width: Self.seekSize, height: Self.seekSize)
        .disabled(display.isUpNext)
    }

    private static let playSize: CGFloat = 46
    private static let seekSize: CGFloat = 32
    private static let ringWidth: CGFloat = 2
}
