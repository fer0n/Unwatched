//
//  AddToLibraryView.swift
//  Unwatched
//

import SwiftUI
import OSLog
import UnwatchedShared
import SwiftData

struct AddToLibraryView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.modelContext) var modelContext
    @Environment(RefreshManager.self) var refresher
    @Environment(NavigationManager.self) var navManager

    /// nil outside the macOS root mount, where the button reports failure itself.
    @Environment(AppNotificationVM.self) private var appNotification: AppNotificationVM?

    /// Mounts the sheets and dialogs without the button; macOS triggers it from the File menu.
    var hidden = false

    @State var addText: String = ""
    @State var addVideosSuccess: Bool?
    @State var isLoadingVideos = false
    @State var addSubscriptionFromText: String?
    @State var textContainingPlaylist: IdentifiableString?

    @State private var subManager = SubscribeManager()

    var body: some View {
        Group {
            if hidden {
                Color.clear.frame(width: 0, height: 0)
            } else {
                pasteButton
            }
        }
        .disabled(subManager.isLoading)
        .onReceive(NotificationCenter.default.publisher(for: .pasteAddToLibrary)) { _ in
            if let text = ClipboardService.get() {
                handleTextFieldSubmit(text)
            }
        }
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
            appNotification?.show("pasteNoUrlFound", isError: true)
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
            await addVideoUrls(videoUrlsLocal, target, showList: playListAsVideos)
        }
    }

    func containsPlaylistUrl(_ str: String) -> Bool {
        let playlistId = UrlService.getPlaylistIdFromUrl(str)
        return playlistId != nil
    }

    func handleAddSubscriptionFromText() async {
        if let text = addSubscriptionFromText {
            let states = await subManager.addSubscriptionFromText(text)
            addSubscriptionFromText = nil
            if states?.count == 1, let subId = states?.first?.subscriptionId,
               let sub: Subscription = modelContext.resolvedModel(withID: subId) {
                navManager.pushSubscription(subscription: sub)
            }
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

    func addVideoUrls(_ urls: [URL], _ target: VideoPlacementArea, showList: Bool) async {
        if !urls.isEmpty {
            isLoadingVideos = true
            do {
                let videoIds = try await VideoService.addForeignUrlsReturningIds(urls, in: target)
                isLoadingVideos = false
                addVideosSuccess = true
                showAddedVideos(videoIds, in: target, showList: showList)
                return
            } catch {
                Log.error("\(error)")
                appNotification?.show(.error(error))
                addVideosSuccess = false
                isLoadingVideos = false
            }
        }
    }

    func showAddedVideos(_ videoIds: [PersistentIdentifier], in target: VideoPlacementArea, showList: Bool) {
        if !showList, videoIds.count == 1,
           let video: Video = modelContext.resolvedModel(withID: videoIds[0]) {
            navManager.pushVideoDetail(video)
        } else if !videoIds.isEmpty {
            let tab: NavigationTab = target == .inbox ? .inbox : .queue
            navManager.clearNavigationStack(tab)
            navManager.navigateTo(tab)
        }
    }
}

#Preview {
    AddToLibraryView()
        .modelContainer(DataProvider.previewContainer)
        .environment(NavigationManager.shared)
        .environment(RefreshManager.shared)
}
