//
//  HideShortsTip.swift
//  Unwatched
//

import TipKit
import UnwatchedShared

struct HideShortsTip: Tip {
    var title: Text {
        Text("HideShortsTip")
    }

    var message: Text? {
        Text("HideShortsTipMessage")
    }

    var image: Image? {
        Image(systemName: "s.circle.fill")
    }

    var actions: [Action] {
        Action(id: Const.hideShortsTipAction) {
            Text("hideShortsTipAction")
                .foregroundStyle(.teal)
        }
        Action(id: Const.discardShortsTipAction) {
            Text("discardShortsTipAction")
                .foregroundStyle(.red)
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
    @AppStorage(Const.shortsPlacement) var shortsPlacement: ShortsPlacement = .show
    @Environment(\.modelContext) var modelContext

    @State var showConfirm = false

    var hideShortsTip = HideShortsTip()

    var body: some View {
        if shortsPlacement == .show {
            hideShortsTipView
        }
    }

    var hideShortsTipView: some View {
        TipView(hideShortsTip) { action in
            if action.id == Const.hideShortsTipAction {
                shortsPlacement = .hide
                VideoService.clearAllYtShortsFromInbox(modelContext)
                hideShortsTip.invalidate(reason: .actionPerformed)
            } else if action.id == Const.discardShortsTipAction {
                showConfirm = true
            }
        }
        .discardShortsActionSheet(isPresented: $showConfirm, onDelete: {
            hideShortsTip.invalidate(reason: .actionPerformed)
        })
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
