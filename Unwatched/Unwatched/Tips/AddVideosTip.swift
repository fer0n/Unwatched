//
//  AddVideosTip.swift
//  Unwatched
//

import SwiftUI
import TipKit

struct AddVideosTip: Tip {
    var title: Text {
        Text("addVideosTip")
    }

    var message: Text? {
        Text("addVideosTipMessage")
    }

    var actions: [Action] {
        Action {
            Text("setupShareSheetAction")
                .foregroundStyle(.teal)
        }
    }
}
