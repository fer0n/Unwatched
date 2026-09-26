//
//  MyBackgroundColor.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct MyBackgroundColor: View {
    var macOS = true
    var visionOS = true

    var body: some View {
        MyRowBackgroundColor(macOS: macOS, visionOS: visionOS)
            .ignoresSafeArea(.all)
    }
}

struct MyRowBackgroundColor: View {
    @Environment(\.colorScheme) var colorScheme

    var macOS = true
    var visionOS = true

    var body: some View {
        // the light sidebar material reads as gray
        (macOS && Const.macOS26 && colorScheme == .dark || visionOS && Device.isVision
            ? Color.clear
            : Color.backgroundColor)
    }
}
