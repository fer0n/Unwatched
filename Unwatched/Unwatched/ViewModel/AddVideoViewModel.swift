//
//  AddVideoViewModel.swift
//  Unwatched
//

import SwiftData
import OSLog
import SwiftUI
import UnwatchedShared

@Observable class AddVideoViewModel {
    var isDragOver = false
    var isLoading = false
    var isSuccess: Bool?

    @MainActor func addUrls(_ urls: [URL], at index: Int = 1) async {
        Log.info("handleUrlDrop inbox \(urls)")
        if urls.count == 0 {
            self.isSuccess = false
            await handleSuccessChange()
            return
        }

        withAnimation {
            isLoading = true
        }
        let task = VideoService.addForeignUrls(
            urls,
            in: .queue,
            at: index
        )
        let success: ()? = try? await task.value
        withAnimation {
            self.isSuccess = success != nil
            self.isLoading = false
        }
        if self.isSuccess != nil {
            await handleSuccessChange()
        }
    }

    @MainActor func handleSuccessChange() async {
        if isSuccess != nil {
            do {
                try await Task.sleep(s: 1.5)
                withAnimation {
                    isSuccess = nil
                }
            } catch {}
        }
    }
}
