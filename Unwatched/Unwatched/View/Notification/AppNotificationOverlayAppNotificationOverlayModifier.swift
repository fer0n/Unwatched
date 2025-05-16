//
//  AppNotificationOverlay.swift
//  Unwatched
//

import SwiftUI

struct AppNotificationOverlayModifier: ViewModifier {
    @Binding var appNotificationVM: AppNotificationVM

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                AppNotificationView(
                    notification: appNotificationVM.currentNotification,
                    onDismiss: { appNotificationVM.isPresented = false }
                )
                .padding(.top, 2)
                .offset(y: appNotificationVM.isPresented ? 0 : -150)
                .opacity(appNotificationVM.isPresented ? 1 : 0)
            }
    }
}

extension View {
    func appNotificationOverlay(_ appNotificationVM: Binding<AppNotificationVM>) -> some View {
        modifier(AppNotificationOverlayModifier(appNotificationVM: appNotificationVM))
    }
}
