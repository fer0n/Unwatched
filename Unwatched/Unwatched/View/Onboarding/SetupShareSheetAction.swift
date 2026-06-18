//
//  SetupShareSheetAction.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

struct SetupShareSheetAction: View {
    @AppStorage(Const.shortcutHasBeenUsed) var shortcutHasBeenUsed = false

    var body: some View {
        if !shortcutHasBeenUsed {
            Link(destination: UrlService.shareShortcutUrl) {
                HStack {
                    Image(systemName: "square.and.arrow.up.on.square.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                    Text("setupShareSheetAction")
                }
            }
            .accessibilityLabel("setupShareSheetAction")
            .bold()
        }
    }
}

#Preview {
    SetupShareSheetAction()
        .modelContainer(DataProvider.previewContainer)
}
