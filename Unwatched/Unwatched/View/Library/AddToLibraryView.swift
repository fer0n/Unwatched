//
//  AddToLibraryView.swift
//  Unwatched
//

import SwiftUI
import TipKit
import OSLog
import UnwatchedShared

struct AddToLibraryView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.modelContext) var modelContext
    @Environment(NavigationManager.self) private var navManager
    @Environment(RefreshManager.self) var refresher

    @AppStorage(Const.themeColor) var theme = ThemeColor()

    @State var addText: String = ""
    @State var addVideosSuccess: Bool?
    @State var isLoadingVideos = false
    @State var videoUrls = [URL]()
    @State var addSubscriptionFromText: String?
    @State var textContainingPlaylist: IdentifiableString?

    var addVideosTip = AddVideosTip()

    @Binding var subManager: SubscribeManager
    var showBrowser: Bool

    var body: some View {
        if showBrowser {
            Button(action: {
                navManager.openUrlInApp(.youtubeStartPage)
            }, label: {
                Label {
                    Text("browser")
                        .foregroundStyle(Color.neutralAccentColor)
                } icon: {
                    Image(systemName: Const.appBrowserSF)
                        .tint(theme.color)
                }
            })
        }

        HStack(spacing: 0) {
            TextField("enterUrls", text: $addText)
                .keyboardType(.webSearch)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
                .submitLabel(.send)
            TextFieldClearButton(text: $addText)
            pasteButton
                .padding(.leading, 5)
        }
        .popoverTip(addVideosTip, arrowEdge: .top, action: { _ in
            if let url = UrlService.shareShortcutUrl {
                UIApplication.shared.open(url)
                addVideosTip.invalidate(reason: .actionPerformed)
            }
        })
        .tint(theme.color)
        .onSubmit {
            handleTextFieldSubmit()
        }
        .disabled(subManager.isLoading)
        .sheet(isPresented: $subManager.showDropResults) {
            AddSubscriptionView(subManager: subManager)
                .environment(\.colorScheme, colorScheme)
        }
        .task(id: addVideosSuccess) {
            await delayedVideoCheckmarkReset()
        }
        .task(id: subManager.isSubscribedSuccess) {
            if subManager.isSubscribedSuccess == true {
                await refresher.refreshAll()
            }
        }
        .task(id: addVideosSuccess) {
            if addVideosSuccess == true {
                await refresher.refreshAll()
            }
        }
        .task(id: subManager.isSubscribedSuccess) {
            await delayedSubscriptionCheckmarkReset()
        }
        .task(id: videoUrls) {
            await addVideoUrls(videoUrls)
        }
        .task(id: addSubscriptionFromText) {
            await handleAddSubscriptionFromText()
        }
        .onDisappear {
            addVideosTip.invalidate(reason: .displayCountExceeded)
        }
        .actionSheet(item: $textContainingPlaylist) { text in
            ActionSheet(title: Text("textContainsPlaylist"),
                        message: Text("textContainsPlaylistMessage"),
                        buttons: [
                            .default(Text("addAsPlaylist")) {
                                addUrlsFromText(text.str)
                            },
                            .default(Text("addAsVideos \(Const.playlistPageRequestLimit * 50)")) {
                                addUrlsFromText(text.str, playListAsVideos: true)
                            },
                            .cancel()
                        ])
        }
    }

    @ViewBuilder var pasteButton: some View {
        let isLoading = subManager.isLoading || isLoadingVideos
        let isSuccess = subManager.isSubscribedSuccess == true || addVideosSuccess == true && isLoading == false
        let failed = subManager.isSubscribedSuccess == false || addVideosSuccess == false

        if isLoading {
            ProgressView()
        } else if failed {
            Image(systemName: Const.clearNoFillSF)
                .accessibilityLabel("failed")
        } else if isSuccess {
            Image(systemName: "checkmark")
                .accessibilityLabel("success")
        } else if addText.isEmpty {
            Button("paste") {
                let text = UIPasteboard.general.string ?? ""
                if !text.isEmpty {
                    handleTextFieldSubmit(text)
                }
            }
            .buttonStyle(CapsuleButtonStyle())
            .tint(.neutralAccentColor)
            .disabled(subManager.isLoading)
        }
    }

    func handleTextFieldSubmit(_ inputText: String? = nil) {
        addVideosTip.invalidate(reason: .actionPerformed)
        let text = inputText ?? self.addText
        guard !text.isEmpty, UrlService.stringContainsUrl(text) else {
            Logger.log.warning("no url found")
            return
        }
        if containsPlaylistUrl(text) {
            textContainingPlaylist = IdentifiableString(str: text)
        } else {
            addUrlsFromText(text)
        }
    }

    func addUrlsFromText(_ text: String, playListAsVideos: Bool = false) {
        print("handlePlaylistUrlText", text)
        var (videoUrlsLocal, rest) = UrlService.extractVideoUrls(text)

        if playListAsVideos {
            let (playlistUrls, newRest) = UrlService.extractPlaylistUrls(rest)
            videoUrlsLocal.append(contentsOf: playlistUrls)
            rest = newRest
        }

        addSubscriptionFromText = rest
        videoUrls = videoUrlsLocal
    }

    func containsPlaylistUrl(_ str: String) -> Bool {
        let playlistId = UrlService.getPlaylistIdFromUrl(str)
        return playlistId != nil
    }

    func handleAddSubscriptionFromText() async {
        if let text = addSubscriptionFromText {
            await subManager.addSubscriptionFromText(text)
            addSubscriptionFromText = nil
        }
    }

    func delayedVideoCheckmarkReset() async {
        if addVideosSuccess == nil {
            return
        }
        addText = ""
        do {
            try await Task.sleep(s: 3)
        } catch { }
        addVideosSuccess = nil
    }

    func delayedSubscriptionCheckmarkReset() async {
        if subManager.isSubscribedSuccess == nil {
            return
        }
        addText = ""
        do {
            try await Task.sleep(s: 3)
        } catch { }
        subManager.isSubscribedSuccess = nil
    }

    func addVideoUrls(_ urls: [URL]) async {
        if !urls.isEmpty {
            videoUrls = []
            isLoadingVideos = true
            let container = modelContext.container
            let task = VideoService.addForeignUrls(urls, in: .queue)
            do {
                try await task.value
                isLoadingVideos = false
                addVideosSuccess = true
                return
            } catch {
                Logger.log.error("\(error)")
                addVideosSuccess = false
                isLoadingVideos = false
            }
        }
    }
}

#Preview {
    AddToLibraryView(subManager: .constant(SubscribeManager()), showBrowser: true)
        .modelContainer(DataProvider.previewContainer)
        .environment(NavigationManager())
        .environment(RefreshManager())
}
