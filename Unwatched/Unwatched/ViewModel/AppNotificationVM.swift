//
//  AppNotificationVM.swift
//  Unwatched
//

import SwiftUI

@Observable class AppNotificationVM {
    var isPresented: Bool = false
    var currentNotification: AppNotificationData?
    var isLoading: Bool = false
    private var hideTask: Task<Void, Never>?
    private var showTask: Task<Void, Never>?

    @MainActor
    func show(_ notification: AppNotificationData) {
        Task {
            await handleShow(notification)
        }
    }

    @MainActor
    func handleShow(_ notification: AppNotificationData) async {
        hideTask?.cancel()
        await showTask?.value

        if isPresented {
            withAnimation(.spring()) {
                currentNotification = notification
            }
        } else {
            currentNotification = notification

            showTask = Task {
                await withCheckedContinuation { continuation in
                    withAnimation(.spring(), completionCriteria: .removed) {
                        isPresented = true
                    } completion: {
                        continuation.resume()
                    }
                }
            }
        }

        if notification.timeout > 0 {
            hideTask = Task {
                try? await Task.sleep(for: .seconds(notification.timeout))
                guard !Task.isCancelled else { return }

                withAnimation(.spring()) {
                    self.isPresented = false
                }
            }
        }
    }
}
