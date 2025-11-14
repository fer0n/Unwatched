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
        (macOS && Const.macOS26 || visionOS && Device.isVision
            ? Color.clear
            : Color.backgroundColor)
            .ignoresSafeArea(.all)
    }
}
