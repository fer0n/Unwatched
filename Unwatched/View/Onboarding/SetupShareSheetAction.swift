//
//  SetupShareSheetAction.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import TipKit

struct SetupShareSheetAction: View {
    @AppStorage(Const.shortcutHasBeenUsed) var shortcutHasBeenUsed = false
    @Query(filter: #Predicate<Subscription> { $0.isArchived == false })
    var subscriptions: [Subscription]

    var body: some View {
        if !shortcutHasBeenUsed, let url = UrlService.shareShortcutUrl {
            Link(destination: url) {
                HStack {
                    Image(systemName: "square.and.arrow.up.on.square.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                    Text("setupShareSheetAction")
                }
            }
            .bold()
        }
    }
}

struct ShareSheetTip: View {
    @AppStorage(Const.shortcutHasBeenUsed) var shortcutHasBeenUsed = false

    var setupShareSheetTip = AddVideosTip()

    var body: some View {
        if !shortcutHasBeenUsed, let url = UrlService.shareShortcutUrl {
            TipView(setupShareSheetTip)
                .onTapGesture {
                    UIApplication.shared.open(url)
                }
        }
    }
}
