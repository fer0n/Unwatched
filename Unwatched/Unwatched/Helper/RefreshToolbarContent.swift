//
//  RefreshToolbarButton.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

struct CoreRefreshButton: View {
    @Environment(\.modelContext) var modelContext
    @Environment(RefreshManager.self) var refresher
    var refreshOnlySubscription: PersistentIdentifier?

    var body: some View {
        HStack {
            Button {
                try? modelContext.save()
                Task { @MainActor in
                    await refresh()
                }
            } label: {
                Image(systemName: refreshIconName)
                    .symbolEffect(.rotate,
                                  options: .speed(1.5),
                                  isActive: refresher.isLoading)
            }
            .accessibilityLabel("refresh")
            .contextMenu {
                Section(refresher.lastRefreshFailed && !refresher.isLoading ? "refreshFailedMessage" : "") {
                    Button {
                        Task { @MainActor in
                            await refresh(hardRefresh: true)
                        }
                    } label: {
                        Label("hardReload", systemImage: "clock.arrow.2.circlepath")
                    }
                }
            }
        }
        .font(.footnote)
        .fontWeight(.bold)
    }

    private var refreshIconName: String {
        refresher.lastRefreshFailed && !refresher.isLoading
            ? Const.refreshFailedSF
            : Const.refreshSF
    }

    @MainActor
    private func refresh(hardRefresh: Bool = false) async {
        if refresher.isLoading { return }
        if let subId = refreshOnlySubscription {
            await refresher.refreshSubscription(subscriptionId: subId, hardRefresh: hardRefresh)
        } else {
            await refresher.refreshAll(hardRefresh: hardRefresh)
        }
    }
}

struct RefreshToolbarContent: ToolbarContent {
    @Environment(RefreshManager.self) var refresher
    var refreshOnlySubscription: PersistentIdentifier?
    var forceNeutral: Bool = false

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .confirmationAction) {
            CoreRefreshButton(refreshOnlySubscription: refreshOnlySubscription)
                .symbolEffect(.pulse,
                              options: .speed(0.8),
                              isActive: refresher.isSyncingIcloud)
                .saturation(refresher.isSyncingIcloud ? 0 : 1)
                .if(forceNeutral) {
                    $0.tint(.neutralAccentColor)
                }
                .myTint(neutral: true)
        }
    }
}

struct ToolbarSpacerWorkaround: ToolbarContent {
    var body: some ToolbarContent {
        ToolbarItem(placement: .secondaryAction) {
            #if os(macOS)
            Button("") {}
                .buttonStyle(.plain)
            #endif
        }
    }
}

// #Preview {
//    RefreshToolbarButton()
//         .environment(RefreshManager())
// }
