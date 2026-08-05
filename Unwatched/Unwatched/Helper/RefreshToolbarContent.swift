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
                Section(lastRefreshFailed && !refresher.isLoading ? "refreshFailedMessage" : "") {
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
        lastRefreshFailed && !refresher.isLoading
            ? Const.refreshFailedSF
            : Const.refreshSF
    }

    /// A handful of dead feeds among many shouldn't flag this; a broad outage should.
    private var lastRefreshFailed: Bool {
        guard refresher.totalSubscriptionsCount > 0 else { return false }
        let failureShare = Double(refresher.failedSubscriptionsCount) / Double(refresher.totalSubscriptionsCount)
        return failureShare >= Const.refreshFailedThreshold
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

/// The refresh button outside a toolbar — the macOS pane header renders its own actions.
struct RefreshButton: View {
    @Environment(RefreshManager.self) var refresher
    var refreshOnlySubscription: PersistentIdentifier?
    var forceNeutral: Bool = false

    var body: some View {
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

struct RefreshToolbarContent: ToolbarContent {
    var refreshOnlySubscription: PersistentIdentifier?
    var forceNeutral: Bool = false

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .confirmationAction) {
            RefreshButton(refreshOnlySubscription: refreshOnlySubscription,
                          forceNeutral: forceNeutral)
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
