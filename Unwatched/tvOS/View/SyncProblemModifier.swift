//
//  SyncProblemModifier.swift
//  UnwatchedTV
//

import CloudKit
import SwiftData
import SwiftUI
import UnwatchedShared

struct SyncProblemModifier: ViewModifier {
    @Environment(SyncManager.self) private var syncer
    @Environment(\.modelContext) private var modelContext
    @State private var accountStatus: CKAccountStatus?

    func body(content: Content) -> some View {
        VStack(spacing: 20) {
            content
            if let problem {
                Label {
                    Text(problem)
                } icon: {
                    Image(systemName: "exclamationmark.icloud")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }
        }
        .task {
            await refreshAccountStatus()
            for await _ in NotificationCenter.default.notifications(named: .CKAccountChanged) {
                await refreshAccountStatus()
            }
        }
    }

    private var cloudKitContainerID: String? {
        modelContext.container.configurations.lazy.compactMap(\.cloudKitContainerIdentifier).first
    }

    private func refreshAccountStatus() async {
        guard let cloudKitContainerID else { return }
        let status = try? await CKContainer(identifier: cloudKitContainerID).accountStatus()
        accountStatus = status ?? .couldNotDetermine
    }

    private var problem: LocalizedStringKey? {
        if cloudKitContainerID == nil {
            return "syncProblemLocalOnly"
        }
        switch accountStatus {
        case .noAccount: return "syncProblemNoAccount"
        case .restricted: return "syncProblemRestricted"
        case .temporarilyUnavailable: return "syncProblemTemporarilyUnavailable"
        case .couldNotDetermine: return "syncProblemUnknown"
        default: break
        }
        if let error = syncer.lastError {
            return "syncProblemError \(error)"
        }
        return nil
    }
}

extension View {
    func syncProblem() -> some View {
        modifier(SyncProblemModifier())
    }
}
