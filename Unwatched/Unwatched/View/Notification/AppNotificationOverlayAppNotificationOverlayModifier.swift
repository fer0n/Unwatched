//
//  AppNotificationOverlay.swift
//  Unwatched
//

import SwiftUI

struct AppNotificationOverlayModifier: ViewModifier {
    @State var appNotificationVM = AppNotificationVM()
    var topPadding: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                AppNotificationView(
                    notification: appNotificationVM.currentNotification,
                    onDismiss: { appNotificationVM.isPresented = false }
                )
                .padding(.top, topPadding)
                .offset(y: appNotificationVM.isPresented ? 0 : -150)
                .opacity(appNotificationVM.isPresented ? 1 : 0)
            }
            .environment(appNotificationVM)
    }
}

extension View {
    func appNotificationOverlay(topPadding: CGFloat = 2) -> some View {
        modifier(AppNotificationOverlayModifier(
                    topPadding: topPadding)
        )
    }
}
