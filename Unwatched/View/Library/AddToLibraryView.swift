//
//  AddToLibraryView.swift
//  Unwatched
//

import SwiftUI

struct AddToLibraryView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(NavigationManager.self) private var navManager
    @Environment(RefreshManager.self) var refresher

    @Binding var subManager: SubscribeManager
    @State var addText: String = ""
    @State var addVideosSuccess: Bool?
    @State var isLoadingVideos = false
    @State var videoUrls = [URL]()

    var body: some View {
        Button(action: {
            navManager.openBrowserUrl = .youtubeStartPage
        }, label: {
            Label("browseFeeds", systemImage: "globe.desk.fill")
        })
        HStack {
            Image(systemName: "link")
                .foregroundStyle(.gray)
            TextField("enterUrls", text: $addText)
                .keyboardType(.alphabet)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
                .submitLabel(.send)
            if !addText.isEmpty {
                TextFieldClearButton(text: $addText)
            }
            pasteButton
        }
        .onSubmit {
            handleTextFieldSubmit()
        }
        .disabled(subManager.isLoading)
        .onAppear {
            subManager.container = modelContext.container
        }
        .sheet(isPresented: $subManager.showDropResults) {
            AddSubscriptionView(subManager: subManager)
        }
        .task(id: addVideosSuccess) {
            await delayedVideoCheckmarkReset()
        }
        .task(id: subManager.isSubscribedSuccess) {
            await delayedSubscriptionCheckmarkReset()
        }
        .task(id: videoUrls) {
            await addVideoUrls(videoUrls)
        }
    }

    var pasteButton: some View {
        ZStack {
            let isLoading = subManager.isLoading || isLoadingVideos
            let isSuccess = subManager.isSubscribedSuccess == true || addVideosSuccess == true && isLoading == false
            let failed = subManager.isSubscribedSuccess == false || addVideosSuccess == false

            if isLoading {
                ProgressView()
            } else if failed {
                Image(systemName: "xmark")
            } else if isSuccess {
                Image(systemName: "checkmark")
            } else if addText.isEmpty {
                Button("paste") {
                    let text = UIPasteboard.general.string ?? ""
                    if !text.isEmpty {
                        handleTextFieldSubmit(text)
                    }
                }
                .buttonStyle(CapsuleButtonStyle())
                .tint(Color.myAccentColor)
                .disabled(subManager.isLoading)
            }
        }
    }

    func handleTextFieldSubmit(_ inputText: String? = nil) {
        let text = inputText ?? self.addText
        guard !text.isEmpty, UrlService.stringContainsUrl(text) else {
            print("no url found")
            return
        }
        let (videoUrlsLocal, rest) = UrlService.extractVideoUrls(text)
        videoUrls = videoUrlsLocal
        subManager.addSubscriptionFromText(rest)
    }

    func delayedVideoCheckmarkReset() async {
        if addVideosSuccess == nil {
            return
        }
        addText = ""
        refresher.refreshAll()
        do {
            try await Task.sleep(s: 3)
            addVideosSuccess = nil
        } catch { }
    }

    func delayedSubscriptionCheckmarkReset() async {
        if subManager.isSubscribedSuccess == nil {
            return
        }
        addText = ""
        refresher.refreshAll()
        do {
            try await Task.sleep(s: 3)
            subManager.isSubscribedSuccess = nil
        } catch { }
    }

    func addVideoUrls(_ urls: [URL]) async {
        if !urls.isEmpty {
            isLoadingVideos = true
            let container = modelContext.container
            let task = VideoService.addForeignUrls(urls, in: .queue, container: container)
            do {
                try await task.value
                isLoadingVideos = false
                addVideosSuccess = true
                return
            } catch {
                print(error)
                addVideosSuccess = false
                isLoadingVideos = false
            }
        }
    }
}

#Preview {
    AddToLibraryView(subManager: .constant(SubscribeManager()))
        .modelContainer(DataController.previewContainer)
        .environment(NavigationManager())
        .environment(RefreshManager())
}
