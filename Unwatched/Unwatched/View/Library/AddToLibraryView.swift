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
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            })
            .foregroundStyle(theme.color)
            .buttonStyle(.plain)
        }

        HStack(spacing: 0) {
            TextField("enterUrls", text: $addText)
                .autocorrectionDisabled(true)
                #if os(iOS)
                .keyboardType(.webSearch)
                .textInputAutocapitalization(.never)
                .submitLabel(.send)
            #endif
            TextFieldClearButton(text: $addText)

            pasteButton
                .padding(.leading, 5)
        }
        .popoverTip(addVideosTip, arrowEdge: .top, action: { _ in
            UrlService.open(UrlService.shareShortcutUrl)
            addVideosTip.invalidate(reason: .actionPerformed)
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
        .task(id: addSubscriptionFromText) {
            await handleAddSubscriptionFromText()
        }
        .onDisappear {
            addVideosTip.invalidate(reason: .displayCountExceeded)
        }
        .confirmationDialog("textContainsPlaylist",
                            isPresented: Binding(
                                get: { textContainingPlaylist != nil },
                                set: { if !$0 { textContainingPlaylist = nil } }
                            ),
                            actions: {
                                Button("addAsPlaylist") {
                                    if let text = textContainingPlaylist {
                                        addUrlsFromText(text.str)
                                    }
                                }
                                Button("addAsVideosToQueue") {
                                    if let text = textContainingPlaylist {
                                        addUrlsFromText(text.str, playListAsVideos: true, target: .queue)
                                    }
                                }
                                Button("addAsVideosToInbox") {
                                    if let text = textContainingPlaylist {
                                        addUrlsFromText(text.str, playListAsVideos: true, target: .inbox)
                                    }
                                }
                                Button("cancel", role: .cancel) {
                                    textContainingPlaylist = nil
                                }
                            },
                            message: { Text("textContainsPlaylistMessage \(Const.playlistPageRequestLimit * 50)") })
    }

    @ViewBuilder var pasteButton: some View {
        let isLoading = subManager.isLoading || isLoadingVideos
        let isSuccess = subManager.isSubscribedSuccess == true || addVideosSuccess == true && isLoading == false
        let failed = subManager.isSubscribedSuccess == false || addVideosSuccess == false

        ZStack {
            if isLoading {
                ProgressView()
                    .frame(width: 10, height: 10)
                    #if os(macOS)
                    .scaleEffect(0.3)
                #endif
            } else if failed {
                Image(systemName: Const.clearNoFillSF)
                    .accessibilityLabel("failed")
            } else if isSuccess {
                Image(systemName: "checkmark")
                    .accessibilityLabel("success")
            }
        }

        PasteButton(payloadType: MultiPayload.self) { payloads in
            guard let payload = payloads.first else {
                return
            }
            switch payload.content {
            case .text(let content):
                handleTextFieldSubmit(content)
            case .url(let url):
                handleTextFieldSubmit(url.absoluteString)
            }
        }
        .buttonBorderShape(.capsule)
        .labelStyle(.iconOnly)
        .tint(theme.color)
        .disabled(subManager.isLoading)
    }

    func handleTextFieldSubmit(_ inputText: String? = nil) {
        addVideosTip.invalidate(reason: .actionPerformed)
        let text = inputText ?? self.addText
        guard !text.isEmpty, UrlService.stringContainsUrl(text) else {
            Log.warning("no url found")
            return
        }
        if containsPlaylistUrl(text) {
            textContainingPlaylist = IdentifiableString(str: text)
        } else {
            addUrlsFromText(text)
        }
    }

    func addUrlsFromText(_ text: String,
                         playListAsVideos: Bool = false,
                         target: VideoPlacementArea = .queue) {
        Log.info("addUrlsFromText: \(text)")
        var (videoUrlsLocal, rest) = UrlService.extractVideoUrls(text)

        if playListAsVideos {
            let (playlistUrls, newRest) = UrlService.extractPlaylistUrls(rest)
            videoUrlsLocal.append(contentsOf: playlistUrls)
            rest = newRest
        }

        // fallback attempt: extract ID directly when nothing worked so far
        if rest == text,
           let url = URL(string: text),
           let youtubeId = UrlService.getYoutubeIdFromUrl(url: url),
           let youtubeUrl = URL(string: UrlService.getNonEmbeddedYoutubeUrl(youtubeId)) {
            videoUrlsLocal.append(youtubeUrl)
        } else {
            addSubscriptionFromText = rest
        }

        Task {
            await addVideoUrls(videoUrlsLocal, target)
        }
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

    func addVideoUrls(_ urls: [URL], _ target: VideoPlacementArea) async {
        if !urls.isEmpty {
            isLoadingVideos = true
            let task = VideoService.addForeignUrls(urls, in: target)
            do {
                try await task.value
                isLoadingVideos = false
                addVideosSuccess = true
                return
            } catch {
                Log.error("\(error)")
                addVideosSuccess = false
                isLoadingVideos = false
            }
        }
    }
}

#Preview {
    AddToLibraryView(subManager: .constant(SubscribeManager()), showBrowser: true)
        .modelContainer(DataProvider.previewContainer)
        .environment(NavigationManager.shared)
        .environment(RefreshManager.shared)
}
