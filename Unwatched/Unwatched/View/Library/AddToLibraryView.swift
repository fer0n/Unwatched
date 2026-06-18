//
//  AddToLibraryView.swift
//  Unwatched
//

import SwiftUI
import OSLog
import UnwatchedShared

struct AddToLibraryView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.modelContext) var modelContext
    @Environment(RefreshManager.self) var refresher

    @State var addText: String = ""
    @State var addVideosSuccess: Bool?
    @State var isLoadingVideos = false
    @State var addSubscriptionFromText: String?
    @State var textContainingPlaylist: IdentifiableString?

    @State private var subManager = SubscribeManager()

    var body: some View {
        pasteButton
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
        let isSuccess = (subManager.isSubscribedSuccess == true || addVideosSuccess == true) && !isLoading
        let failed = subManager.isSubscribedSuccess == false || addVideosSuccess == false

        Button {
            if let text = ClipboardService.get() {
                handleTextFieldSubmit(text)
            }
        } label: {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else if failed {
                Image(systemName: Const.clearNoFillSF)
            } else if isSuccess {
                Image(systemName: "checkmark")
            } else {
                Image(systemName: "doc.on.clipboard.fill")
            }
        }
        .accessibilityLabel("pasteUrl")
    }

    func handleTextFieldSubmit(_ inputText: String? = nil) {
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
           let youtubeUrl = URL(string: UrlService.getNonEmbeddedYoutubeUrl(
                                    youtubeId,
                                    UrlService.getStartTimeFromUrl(url))
           ) {
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
    AddToLibraryView()
        .modelContainer(DataProvider.previewContainer)
        .environment(NavigationManager.shared)
        .environment(RefreshManager.shared)
}
