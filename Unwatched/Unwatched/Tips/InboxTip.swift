//
//  InboxTip.swift
//  Unwatched
//

import Foundation
import SwiftUI
import TipKit

struct InboxSwipeTip: Tip {
    var title: Text {
        Text("InboxSwipeTip")
    }

    var message: Text? {
        Text("InboxSwipeTipMessage")
    }

    var image: Image? {
        Image(systemName: "arrow.left.and.line.vertical.and.arrow.right")
    }
}
