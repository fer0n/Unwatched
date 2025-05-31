//
//  HideShortsTip.swift
//  Unwatched
//

import TipKit
import UnwatchedShared

struct HideShortsTip: Tip {
    var title: Text {
        Text("hideShortsTip")
    }

    var message: Text? {
        Text("hideShortsTipMessage")
    }

    var image: Image? {
        Image(systemName: "s.circle.fill")
    }

    var actions: [Action] {
        Action {
            Text("hideShortsTipAction")
                .foregroundStyle(.teal)
        }
    }

    @Parameter
    static var clearedShorts: Int = 0

    var rules: [Rule] {
        [
            #Rule(Self.$clearedShorts) {
                $0 >= 3
            }
        ]
    }
}

struct HideShortsTipView: View {
    @CloudStorage(Const.defaultShortsSetting) var defaultShortsSetting: ShortsSetting = .show
    @Environment(\.modelContext) var modelContext

    var hideShortsTip = HideShortsTip()

    var body: some View {
        if defaultShortsSetting == .show {
            hideShortsTipView
        }
    }

    var hideShortsTipView: some View {
        TipView(hideShortsTip) { _ in
            VideoService.clearAllYtShortsFromInbox(modelContext)
            defaultShortsSetting = .hide
            hideShortsTip.invalidate(reason: .actionPerformed)
        }
        .tipBackground(Color.insetBackgroundColor)
        .listRowBackground(Color.backgroundColor)
    }
}

#Preview {
    let tip = HideShortsTip()
    return HStack {
        TipView(tip)
    }
}
