//
//  DropUrlArea.swift
//  Unwatched
//

import Foundation
import SwiftUI
import OSLog

struct DropUrlArea<Content: View>: View {
    @AppStorage(Const.themeColor) var theme: ThemeColor = Color.defaultTheme
    @Environment(\.modelContext) var modelContext

    @State var isDragOver = false
    @State var isLoading = false
    @State var isSuccess: Bool?
    @State var droppedUrls = [URL]()

    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        let showDropArea = isDragOver || isLoading || isSuccess != nil

        VStack {
            if showDropArea {
                Spacer()
                    .frame(height: 40)
            }
            if showDropArea {
                dropAreaContent
                    .frame(maxWidth: .infinity)
                Spacer()
                    .frame(height: 40)
            } else {
                content
            }
        }
        .background(showDropArea ? theme.color : .clear)
        .tint(.neutralAccentColor)
        .dropDestination(for: URL.self) { items, _ in
            droppedUrls = items
            return true
        } isTargeted: { targeted in
            print("targeted", targeted)
            withAnimation {
                isDragOver = targeted
            }
        }
        .sensoryFeedback(Const.sensoryFeedback, trigger: showDropArea)
        .task(id: isSuccess) {
            await handleSuccessChange()
        }
        .task(id: droppedUrls) {
            guard !droppedUrls.isEmpty else {
                return
            }
            await handleUrlDrop(droppedUrls)
        }
    }

    var dropAreaContent: some View {
        ZStack {
            let size: CGFloat = 20

            if isLoading {
                ProgressView()
            } else if isSuccess == true {
                Image(systemName: "checkmark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            } else if isSuccess == false {
                Image(systemName: "xmark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            } else {
                VStack {
                    Image(systemName: Const.queueTagSF)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                    Text("dropVideoUrlsHere")
                        .fontWeight(.medium)
                }
            }
        }
        .foregroundStyle(.white)
    }

    @MainActor func handleUrlDrop(_ urls: [URL]) async {
        Logger.log.info("handleUrlDrop inbox \(urls)")
        withAnimation {
            isLoading = true
        }
        let container = modelContext.container
        let task = VideoService.addForeignUrls(urls, in: .queue, container: container)
        let success: ()? = try? await task.value
        withAnimation {
            self.isSuccess = success != nil
            self.isLoading = false
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
