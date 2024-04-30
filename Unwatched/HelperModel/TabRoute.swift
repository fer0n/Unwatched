//
//  TabRoute.swift
//  Unwatched
//

import SwiftUI

struct TabRoute {
    var view: AnyView
    var image: Image
    var text: LocalizedStringKey
    var tag: NavigationTab
    var showBadge: Bool = false
    var show: Bool = true
}
