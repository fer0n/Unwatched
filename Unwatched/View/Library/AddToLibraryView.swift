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

    var body: some View {
        Button(action: {
            navManager.showBrowserSheet = true
        }, label: {
            Label("browseFeeds", systemImage: "globe.desk.fill")
        })
        HStack {
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
    }

    var pasteButton: some View {
        ZStack {
            let isLoading = subManager.isLoading || isLoadingVideos
            let isSuccess = subManager.isSubscribedSuccess == true || addVideosSuccess == true && isLoading == false

            if isLoading {
                ProgressView()
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
        .onChange(of: subManager.isSubscribedSuccess) {
            delayedSubscriptionCheckmarkReset()
        }
        .onChange(of: addVideosSuccess) {
            delayedVideoCheckmarkReset()
        }
    }

    func handleTextFieldSubmit(_ inputText: String? = nil) {
        let text = inputText ?? self.addText
        guard !text.isEmpty, UrlService.stringContainsUrl(text) else {
            print("no url found")
            return
        }
        let (videoUrls, rest) = UrlService.extractVideoUrls(text)
        addVideoUrls(videoUrls)
        subManager.addSubscriptionFromText(rest)
    }

    func delayedVideoCheckmarkReset() {
        if addVideosSuccess != true {
            return
        }
        addText = ""
        refresher.refreshAll()
        Task {
            await Task.sleep(s: 3)
            await MainActor.run {
                addVideosSuccess = nil
            }
        }
    }

    func delayedSubscriptionCheckmarkReset() {
        if subManager.isSubscribedSuccess != true {
            return
        }
        addText = ""
        refresher.refreshAll()
        Task {
            await Task.sleep(s: 3)
            await MainActor.run {
                subManager.isSubscribedSuccess = nil
            }
        }
    }

    func addVideoUrls(_ urls: [URL]) {
        if !urls.isEmpty {
            isLoadingVideos = true
            let container = modelContext.container
            let task = VideoService.addForeignUrls(urls, in: .queue, container: container)
            Task {
                do {
                    try await task.value
                    await MainActor.run {
                        isLoadingVideos = false
                        addVideosSuccess = true
                        return
                    }
                } catch {
                    print(error)
                }
                await MainActor.run {
                    isLoadingVideos = false
                }
            }
        }
        print("urls", urls)
    }
}

#Preview {
    AddToLibraryView(subManager: .constant(SubscribeManager()))
        .modelContainer(DataController.previewContainer)
        .environment(NavigationManager())
        .environment(RefreshManager())
}
