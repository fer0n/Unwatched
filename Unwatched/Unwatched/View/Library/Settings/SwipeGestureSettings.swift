//
//  SwipeGestureSettings.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct SwipeGestureSettings: View {
    @AppStorage(Const.swipeGestureUp) var swipeGestureUp = true
    @AppStorage(Const.swipeGestureDown) var swipeGestureDown = true
    @AppStorage(Const.swipeGestureLeft) var swipeGestureLeft = true
    @AppStorage(Const.swipeGestureRight) var swipeGestureRight = true

    var body: some View {
        MySection("swipeGestures") {
            Toggle(isOn: $swipeGestureUp) {
                Text("up")
            }
            Toggle(isOn: $swipeGestureDown) {
                Text("down")
            }
            Toggle(isOn: $swipeGestureLeft) {
                Text("left")
            }
            Toggle(isOn: $swipeGestureRight) {
                Text("right")
            }
        }
    }
}
