//
//  YtBrowserTip.swift
//  Unwatched
//

import Foundation
import SwiftUI
import TipKit

struct AddButtonTip: Tip {
    var title: Text {
        Text("addSubscriptionButtonTip")
    }

    var message: Text? {
        Text("addSubscriptionButtonTipMessage")
    }
}
