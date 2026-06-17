//
//  Animation.swift
//  Unwatched
//

import SwiftUI

extension Animation {
    /// Short, snappy animation used when the scrubber jumps to a new seek target, so it reads
    /// as a quick jump rather than a slow glide.
    static let seekScrubber = Animation.snappy(duration: 0.12)
}
