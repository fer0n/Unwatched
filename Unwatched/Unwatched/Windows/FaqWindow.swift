//
//  FaqWindow.swift
//  Unwatched
//

import SwiftUI

struct FaqWindow: View {
    var body: some View {
        ScrollView {
            FaqView()
                .padding()
        }
        .frame(width: 600, height: 800)
        #if os(macOS)
        .toolbarBackground(Color.myBackgroundGray, for: .windowToolbar)
        #endif
    }
}
