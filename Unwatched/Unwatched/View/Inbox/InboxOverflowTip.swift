//
//  InboxOverflowTip.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct InboxOverflowTipView: View {
    @Environment(\.modelContext) var modelContext
    @AppStorage(Const.themeColor) var theme = ThemeColor()

    @AppStorage(Const.inboxFullDismissedDate)
    var inboxFullDismissedDate = Date.distantPast.timeIntervalSinceReferenceDate
    @State private var triggerAction = false

    var body: some View {
        if shouldShow {
            HStack(alignment: .top) {
                Image(systemName: Const.inboxTabFullSF)
                    .symbolVariant(.fill)
                    .font(.title)
                    .foregroundStyle(theme.color)

                VStack(alignment: .leading) {
                    HStack {
                        Text("inboxOverflowTip")
                            .font(.headline)

                        Spacer()

                        Button {
                            setDismissedDate()
                        } label: {
                            Image(systemName: Const.clearNoFillSF)
                                .font(.headline)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Text("inboxOverflowTipMessage")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Divider()

                    Button {
                        let count = CleanupService.clearOldInboxEntries(
                            keep: Const.inboxOverflowKeepCount,
                            modelContext
                        )
                        if count != nil {
                            setDismissedDate()
                        }
                    } label: {
                        Text("inboxOverflowTipAction \(Const.inboxOverflowKeepCount)")
                    }
                    .buttonStyle(.borderless)

                    Divider()

                    Button(role: .destructive) {
                        triggerAction = true
                    } label: {
                        Text("clearAll")
                    }
                    .buttonStyle(.borderless)

                }
            }
            .clearConfirmation(clearAll: clearAll, triggerAction: $triggerAction)
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(Color.insetBackgroundColor)
            }
            .listRowBackground(Color.backgroundColor)
        }
    }

    var shouldShow: Bool {
        dismissedDate.addingTimeInterval(60 * 60 * 24 * 7) < Date.now // 1 week
    }

    var dismissedDate: Date {
        Date(timeIntervalSinceReferenceDate: inboxFullDismissedDate)
    }

    func clearAll() {
        VideoService.clearAllInboxEntries(modelContext)
    }

    func setDismissedDate() {
        withAnimation {
            inboxFullDismissedDate = Date.now.timeIntervalSinceReferenceDate
        }
    }
}
