//
//  CleanupHiddenShortsView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct CleanupHiddenShortsView: View {
    @State private var isCleaningShorts = false
    @State private var cleanupDeletedCount: Int?

    var body: some View {
        MySection {
            Button {
                cleanupHiddenShorts()
            } label: {
                HStack {
                    Text("cleanupHiddenShorts")
                    if isCleaningShorts {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(isCleaningShorts)

            if let cleanupDeletedCount {
                Text("deleteHiddenShorts \(cleanupDeletedCount)")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func cleanupHiddenShorts() {
        isCleaningShorts = true
        cleanupDeletedCount = nil
        Task {
            do {
                let count = try await CleanupService.cleanupHiddenShorts().value
                await MainActor.run {
                    withAnimation {
                        self.cleanupDeletedCount = count
                    }
                    self.isCleaningShorts = false
                }
            } catch {
                await MainActor.run {
                    self.isCleaningShorts = false
                }
            }
        }
    }
}
