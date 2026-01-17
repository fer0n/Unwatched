//
//  StatsChannelRow.swift
//  Unwatched
//

import SwiftUI

struct StatsChannelRow: View {
    let channel: ChannelStat
    let viewModel: StatsVM
    let selectedDate: Date

    @State private var showDeleteAlert = false

    var body: some View {
        HStack {
            Text(channel.channelName)
            Spacer()
            Text(Duration.seconds(channel.watchTime).formatted(.time(pattern: .hourMinuteSecond)))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                showDeleteAlert = true
            } label: {
                Label("delete", systemImage: "trash")
            }
        }
        .confirmationDialog("reallyDelete", isPresented: $showDeleteAlert, titleVisibility: .visible) {
            Button("delete", role: .destructive) {
                Task {
                    await viewModel.deleteStats(date: selectedDate, channelId: channel.channelId)
                }
            }
            Button("cancel", role: .cancel) {}
        } message: {
            Text("deleteStatsConfirmation \(channel.channelName)")
        }
    }
}
