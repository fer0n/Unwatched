//
//  EmptyView.swift
//  UnwatchedTV
//

import SwiftUI
import UnwatchedShared

struct EmptyQueueView: View {
    @Environment(SyncManager.self) var syncer

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

            ProgressView()
                .opacity(syncer.isSyncing ? 1 : 0)
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
        Button("fillData", systemImage: "plus", action: fillData)
    }

    func fillData() {
        DataProvider.fillWithTestData(modelContext)
    }
}

#Preview {
    EmptyQueueView()
        .environment(SyncManager())
    //        .modelContainer(DataController.previewContainer)
}
