//
//  SyncRequestAlert.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct SyncRequestAlert: ViewModifier {
    @AppStorage(Const.enableIcloudSync) var enableIcloudSync = false
    @AppStorage(Const.onboardingCompleted) var onboardingCompleted = false

    @State private var acceptedRequest: SyncRequest?

    func body(content: Content) -> some View {
        content
            .alert("syncRequestAlertTitle", isPresented: Binding(
                get: { acceptedRequest != nil },
                set: { if !$0 { acceptedRequest = nil } }
            )) {
                Button("restartNow") { exit(0) }
                Button("syncRequestLater", role: .cancel) { }
            } message: {
                if let name = acceptedRequest?.fromKind.productName {
                    Text("syncRequestAlertMessage \(name)")
                } else {
                    Text("syncRequestAlertMessageGeneric")
                }
            }
            .task(id: enableIcloudSync) {
                guard !enableIcloudSync else { return }
                acceptPendingRequest()
                for await _ in SyncHandoff.requestChanges {
                    acceptPendingRequest()
                }
            }
    }

    private func acceptPendingRequest() {
        guard onboardingCompleted, let request = SyncHandoff.pendingRequest() else { return }
        SyncHandoff.markHandled(request)
        enableIcloudSync = true
        SyncHandoff.publishSyncState(true)
        Signal.log("SyncRequest.Accepted")
        acceptedRequest = request
    }
}

extension View {
    func acceptsSyncRequests() -> some View {
        modifier(SyncRequestAlert())
    }
}
