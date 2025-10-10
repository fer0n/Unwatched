//
//  MyBackgroundColor.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct MyBackgroundColor: View {
    var body: some View {
        (Const.macOS26 ? Color.clear : Color.backgroundColor)
            .ignoresSafeArea(.all)
    }
}
