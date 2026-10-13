//
//  EmptyView.swift
//  UnwatchedTV
//

import SwiftUI
import UnwatchedShared
import SwiftData

struct EmptyQueueView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "cloud.fill")
                .font(.title)

            Text("videosUnavailable")
                .font(.title3)
                .padding(.bottom, 5)

            Text("videosUnavailableDescription")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            SyncStatusLabel()
                .font(.caption)
                .padding(.top, 10)

            #if DEBUG
            AddTestDataButton()
            #endif
        }
        .frame(maxWidth: 600)
    }
}

struct AddTestDataButton: View {
    @Environment(\.modelContext) var modelContext

    var body: some View {
        Button {
            fillData()
        } label: {
            HStack(spacing: 20) {
                Image(systemName: "plus")
                Text(verbatim: "Test Data")
            }
        }
    }

    func fillData() {
        DataProvider.fillWithTestData(modelContext)
    }
}

#Preview {
    EmptyQueueView()
        .environment(SyncManager())
        .environment(SyncProgress())
}
