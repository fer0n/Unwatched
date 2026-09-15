//
//  SyncingLabel.swift
//  UnwatchedWatch
//

import SwiftUI

/// How far the mirror has got, on the queue's own row and on the sync screen.
struct SyncingLabel: View {
    let isImporting: Bool
    let share: Double?

    var body: some View {
        HStack(spacing: 6) {
            if isImporting {
                Image(systemName: "progress.indicator")
                    .symbolEffect(.variableColor.iterative)
            }
            Text("watchSyncingShort")
            if let share {
                Spacer(minLength: 4)
                Text(share, format: .percent.precision(.fractionLength(2)))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
        }
    }
}
