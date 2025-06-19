//
//  SpeedSliderBackground.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct SpeedSliderBackground: View {
    var onTap: (_ speed: Double) -> Void
    var showDecimalHighlights: Bool = false
    var thumbSize: CGFloat
    var indicatorSpacing: CGFloat

    var body: some View {
        let highlighted: [Double] = showDecimalHighlights
            ? Const.highlightedPlaybackSpeeds
            : Const.highlightedSpeedsInt
        let frameSize: CGFloat = 3

        HStack(spacing: 0) {
            ForEach(Const.speeds, id: \.self) { speed in
                let isHightlighted = highlighted.contains(speed)
                let foregroundColor: Color = .foregroundGray.opacity(0.5)

                ZStack {
                    Circle()
                        .fill(isHightlighted ? .clear : foregroundColor)
                        .foregroundStyle(isHightlighted ? .clear : foregroundColor)
                        .frame(width: frameSize, height: frameSize)
                        .frame(maxWidth: .infinity, maxHeight: thumbSize)
                        .frame(minWidth: frameSize + indicatorSpacing)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onTap(speed)
                        }
                    if isHightlighted {
                        Text(SpeedControlViewModel.formatSpeed(speed))
                            .font(.system(size: 12))
                            .fontWeight(.heavy)
                            .fontWidth(.compressed)
                            .foregroundStyle(foregroundColor)
                            .allowsHitTesting(false)
                            .frame(minWidth: 10)
                            .frame(width: frameSize, height: frameSize)
                    }
                }
            }
        }
    }
}
