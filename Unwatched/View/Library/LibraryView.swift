//
//  LibraryView.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct LibraryView: View {
    @AppStorage(Const.subscriptionSortOrder) var subscriptionSortOrder: SubscriptionSorting = .recentlyAdded
    @Environment(\.modelContext) var modelContext
    @Environment(NavigationManager.self) private var navManager
    @Environment(RefreshManager.self) var refresher

    @Query var subscriptions: [Subscription]
    @Query(filter: #Predicate<Subscription> { $0.isArchived == true })

    var sidedloadedSubscriptions: [Subscription]

    @State var showBrowserSheet = false
    @State var subManager = SubscribeManager()
    @State var text: String = ""
    @State var isDragOver: Bool = false
    @State var isLoadingVideos = false
    @State var addVideosSuccess: Bool?

    var hasSideloads: Bool {
        !sidedloadedSubscriptions.isEmpty
    }

    var body: some View {
        let topListItemId = NavigationManager.getScrollId("library")
        @Bindable var navManager = navManager
        NavigationStack(path: $navManager.presentedLibrary) {
            List {
                Section {
                    NavigationLink(value: LibraryDestination.settings) {
                        LibraryNavListItem("settings", systemName: Const.settingsViewSF)
                    }
                    .id(topListItemId)
                }
                Section {
                    NavigationLink(value: LibraryDestination.allVideos) {
                        LibraryNavListItem("allVideos",
                                           systemName: "play.rectangle.on.rectangle.fill",
                                           .cyan)
                    }
                    NavigationLink(value: LibraryDestination.watchHistory) {
                        LibraryNavListItem("watched",
                                           systemName: "checkmark.circle.fill",
                                           .green)
                    }
                    NavigationLink(value: LibraryDestination.bookmarkedVideos) {
                        LibraryNavListItem("bookmarkedVideos",
                                           systemName: "bookmark.circle.fill",
                                           .blue)
                    }
                    if hasSideloads {
                        NavigationLink(value: LibraryDestination.sideloading) {
                            LibraryNavListItem("sideloads",
                                               systemName: "arrow.forward.circle.fill",
                                               .purple)
                        }
                    }
                }

                Section("subscriptions") {
                    if subscriptions.isEmpty {
                        searchBar
                        dropArea
                            .listRowInsets(EdgeInsets())
                    } else {
                        searchBar

                        SubscriptionListView(
                            sort: subscriptionSortOrder,
                            manualFilter: { text.isEmpty || $0.title.localizedStandardContains(text) }
                        )
                        .dropDestination(for: URL.self) { items, _ in
                            handleUrlDrop(items)
                            return true
                        }
                    }
                }
            }
            .onAppear {
                navManager.topListItemId = topListItemId
            }
            .navigationTitle("library")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Subscription.self) { sub in
                SubscriptionDetailView(subscription: sub)
            }
            .navigationDestination(for: LibraryDestination.self) { value in
                switch value {
                case .allVideos:
                    AllVideosView()
                case .watchHistory:
                    WatchHistoryView()
                case .sideloading:
                    SideloadingView()
                case .settings:
                    SettingsView()
                case .userData:
                    BackupView()
                case .bookmarkedVideos:
                    BookmarkedVideosView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        ForEach(SubscriptionSorting.allCases, id: \.self) { sort in
                            Button {
                                subscriptionSortOrder = sort
                            } label: {
                                HStack {
                                    Image(systemName: sort.systemName)
                                    Text(sort.description)
                                }
                            }
                            .disabled(subscriptionSortOrder == sort)
                        }
                    } label: {
                        Image(systemName: Const.filterSF)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        showBrowserSheet = true
                    }, label: {
                        Image(systemName: "plus")
                    })
                }
                RefreshToolbarButton()
            }
        }
        .onAppear {
            subManager.container = modelContext.container
        }
        .sheet(isPresented: $showBrowserSheet) {
            BrowserView()
                .onDisappear {

                }
        }
        .sheet(isPresented: $subManager.showDropResults) {
            AddSubscriptionView(subManager: subManager)
        }
    }

    var dropArea: some View {
        ZStack {
            Rectangle()
                .fill(isDragOver ? Color.teal.opacity(0.1) : .clear)

            VStack(spacing: 10) {
                Text("dropUrlsHere")
                    .font(.title2)
                    .bold()
                    .foregroundStyle(.gray)
                Text("dropSubscriptionHelper")
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                    .tint(.teal)
            }
            .padding(25)
        }
        .dropDestination(for: URL.self) { items, _ in
            handleUrlDrop(items)
            return true
        } isTargeted: { targeted in
            isDragOver = targeted
        }
    }

    var searchBar: some View {
        HStack(spacing: 0) {
            let isLoading = subManager.isLoading || isLoadingVideos
            let isSuccess = subManager.isSubscribedSuccess == true || addVideosSuccess == true && isLoading == false

            Text("")
            TextField("searchLibraryOrEnterUrl", text: $text)
                .submitLabel(.done)
                .onSubmit {
                    handleTextFieldSubmit()
                }
                .disabled(subManager.isLoading)
            if isLoading {
                ProgressView()
            } else if isSuccess {
                Image(systemName: "checkmark")
            } else if text.isEmpty {
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

    func delayedVideoCheckmarkReset() {
        if addVideosSuccess != true {
            return
        }
        text = ""
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
        text = ""
        refresher.refreshAll()
        Task {
            await Task.sleep(s: 3)
            await MainActor.run {
                subManager.isSubscribedSuccess = nil
            }
        }
    }

    func handleTextFieldSubmit(_ inputText: String? = nil) {
        let text = inputText ?? self.text
        guard UrlService.stringContainsUrl(text) else {
            print("no url found")
            return
        }
        let (videoUrls, rest) = UrlService.extractVideoUrls(text)
        addVideoUrls(videoUrls)
        subManager.addSubscriptionFromText(rest)
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

    func handleUrlDrop(_ urls: [URL]) {
        print("handleUrlDrop inbox", urls)
        subManager.addSubscription(from: urls)
    }
}

enum LibraryDestination {
    case sideloading
    case watchHistory
    case allVideos
    case bookmarkedVideos
    case userData
    case settings
}

#Preview {
    LibraryView()
        .modelContainer(DataController.previewContainer)
        .environment(NavigationManager())
        .environment(PlayerManager())
        .environment(RefreshManager())
}
