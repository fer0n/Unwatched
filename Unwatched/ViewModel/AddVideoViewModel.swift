//
//  AddVideoViewModel.swift
//  Unwatched
//

import SwiftData
import OSLog
import SwiftUI

@Observable class AddVideoViewModel {
    var isDragOver = false
    var isLoading = false
    var isSuccess: Bool?

    var container: ModelContainer?

    @MainActor func addUrls(_ urls: [URL]) async {
        Logger.log.info("handleUrlDrop inbox \(urls)")
        withAnimation {
            isLoading = true
        }
        guard let container = container else {
            Logger.log.warning("No container found")
            return
        }
        let task = VideoService.addForeignUrls(urls, in: .queue, container: container)
        let success: ()? = try? await task.value
        withAnimation {
            self.isSuccess = success != nil
            self.isLoading = false
        }
        if self.isSuccess == true {
            await handleSuccessChange()
        }
    }

    @MainActor func handleSuccessChange() async {
        if isSuccess != nil {
            do {
                try await Task.sleep(s: 1)
                withAnimation {
                    isSuccess = nil
                }
            } catch {}
        }
    }
}
