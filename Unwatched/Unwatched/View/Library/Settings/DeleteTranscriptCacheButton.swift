//
//  DeleteTranscriptCacheButton.swift
//  Unwatched
//

import SwiftUI

struct DeleteTranscriptCacheButton: View {
    @State var isDeletingTask: Task<(), Never>?

    var body: some View {
        Button(role: .destructive, action: {
            deleteTranscriptCache()
        }, label: {
            if isDeletingTask != nil {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Text("deleteTranscriptCache")
            }
        })
        .task(id: isDeletingTask) {
            guard isDeletingTask != nil else { return }
            await isDeletingTask?.value
            isDeletingTask = nil
        }
    }

    func deleteTranscriptCache() {
        if isDeletingTask != nil { return }
        isDeletingTask = Task {
            let task = TranscriptService.deleteCache()
            try? await task.value
        }
    }
}
