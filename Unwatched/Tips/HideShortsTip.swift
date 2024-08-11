//
//  HideShortsTip.swift
//  Unwatched
//

import TipKit

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
        Action {
            Text("HideShortsTipAction")
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

#Preview {
    let tip = HideShortsTip()
    return HStack {
        TipView(tip)
    }
}
