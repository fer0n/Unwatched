//
//  DeleteImageCacheButton.swift
//  Unwatched
//

import SwiftUI
import OSLog

struct DeleteImageCacheButton: View {
    @Environment(\.modelContext) var modelContext
    @Environment(ImageCacheManager.self) var cacheManager

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
        cacheManager.clearCacheAll()
        let container = cacheManager.container
        isDeletingTask = Task {
            guard let container = container else {
                Logger.log.warning("No image container to delete images")
                return
            }
            let task = ImageService.deleteAllImages()
            try? await task.value
        }
    }
}
