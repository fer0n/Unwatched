//
//  YtBrowserTip.swift
//  Unwatched
//

import Foundation
import SwiftUI
import TipKit

struct YtBrowserTip: Tip {
    var title: Text {
        Text("addSubscriptionTip")
    }

    var message: Text? {
        Text("addSubscriptionTipMessage")
    }

    var image: Image? {
        Image(systemName: "person.circle.fill")
    }
}

struct AddButtonTip: Tip {
    var title: Text {
        Text("addSubscriptionButtonTip")
    }

    var message: Text? {
        Text("addSubscriptionButtonTipMessage")
    }
}
