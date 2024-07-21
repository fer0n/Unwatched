//
//  DeleteImageCacheButton.swift
//  Unwatched
//

import SwiftUI

struct DeleteImageCacheButton: View {
    @Environment(\.modelContext) var modelContext
    @State var isDeletingTask: Task<(), Never>?

    var body: some View {
        Button(role: .destructive, action: {
            deleteImageCache()
        }, label: {
            if isDeletingTask != nil {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Text("deleteImageCache")
            }
        })
        .task(id: isDeletingTask) {
            guard isDeletingTask != nil else { return }
            await isDeletingTask?.value
            isDeletingTask = nil
        }
    }

    func deleteImageCache() {
        if isDeletingTask != nil { return }
        let container = modelContext.container
        isDeletingTask = Task {
            let task = ImageService.deleteAllImages(container)
            try? await task.value
        }
    }
}
