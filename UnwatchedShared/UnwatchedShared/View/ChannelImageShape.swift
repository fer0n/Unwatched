//
//  ChannelImageShape.swift
//  UnwatchedShared
//

import SwiftUI

/// The shape channel avatars and podcast artwork are clipped to.
public struct ChannelImageShape: Shape {
    /// Corner radius as a share of the image's side, so the rounding reads the same at every size.
    public static let cornerFactor: CGFloat = 0.22

    public init() { }

    public func path(in rect: CGRect) -> Path {
        RoundedRectangle(
            cornerRadius: min(rect.width, rect.height) * Self.cornerFactor,
            style: .continuous
        )
        .path(in: rect)
    }
}

public extension View {
    /// Clips a channel avatar (circle) or podcast cover (`ChannelImageShape`).
    @ViewBuilder
    func channelImageClip(isPodcast: Bool) -> some View {
        if isPodcast {
            clipShape(ChannelImageShape())
        } else {
            clipShape(Circle())
        }
    }
}
