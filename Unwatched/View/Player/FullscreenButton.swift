//
//  FullscreenButton.swift
//  Unwatched
//

import SwiftUI

struct FullscreenButton: View {

    @Binding var playVideoFullscreen: Bool

    var body: some View {
        Toggle(isOn: $playVideoFullscreen) {
            Image(systemName: playVideoFullscreen
                    ? "rectangle.inset.filled"
                    : "rectangle.slash.fill")
        }
        .toggleStyle(OutlineToggleStyle())
    }
}
