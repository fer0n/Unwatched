//
//  ImportSubscriptionsWindow.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct ImportSubscriptionsWindow: View {
    var body: some View {
        ImportSubscriptionsView()
            .background(Color.backgroundColor)
            #if os(macOS)
            .toolbarBackground(Color.myBackgroundGray, for: .windowToolbar)
        #endif
    }
}

#Preview {
    ImportSubscriptionsWindow()
        .modelContainer(DataProvider.previewContainer)
        .environment(RefreshManager())
}
