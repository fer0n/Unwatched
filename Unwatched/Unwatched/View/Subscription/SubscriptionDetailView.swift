//
//  SubscriptionDetailView.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

struct SubscriptionDetailView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(NavigationManager.self) var navManager

    @State var isLoading = false
    @State var subscribeManager = SubscribeManager()
    @State var requiresUnsubscribe = false
    @State var loadNewVideosTask: Task<(), Never>?
    @State var showTitle: Bool = false
    @State var showFilter = false

    @Bindable var subscription: Subscription

    var body: some View {
        VStack {
            List {
                VStack {
                    SubscriptionInfoDetails(subscription: subscription,
                                            requiresUnsubscribe: $requiresUnsubscribe,
                                            showFilter: $showFilter)
                        .onAppear {
                            withAnimation(.default.speed(1.5)) {
                                showTitle = false
                            }
                        }
                        .onDisappear {
                            withAnimation(.default.speed(1.5)) {
                                showTitle = true
                            }
                        }
                }
                #if os(visionOS)
                .listRowInsets(EdgeInsets())
                #else
                .imageAccentBackground(url: imageUrl)
                #endif
                .myListRowBackground()

                if showFilter {
                    Button {
                        showFilter = false
                    } label: {
                        Text("filterPreviewClose")
                            .padding(.horizontal, 5)
                    }
                    #if !os(visionOS)
                    .apply {
                        if #available(iOS 26.0, macOS 26.0, *) {
                            $0.glassEffect(.regular.interactive())
                        } else {
                            $0
                        }
                    }
                    .foregroundStyle(Color.automaticBlack)
                    .tint(Color.insetBackgroundColor)
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    #endif
                    .buttonStyle(.bordered)
                    .myListRowBackground()
                    .listRowSeparator(.hidden)
                    .frame(maxWidth: .infinity, alignment: .center)

                    SubscriptionTitleFitlerPreview(subscription: subscription)
                        .listRowSeparator(.hidden)
                } else {
                    VideoListView(subscriptionId: subscription.persistentModelID)
                }
            }
            .scrollContentBackground(.hidden)
            #if !os(visionOS)
            .apply {
                if #available(iOS 26.0, macOS 26.0, *) {
                    $0
                        .scrollEdgeEffectHidden(!showTitle, for: .top)
                } else {
                    $0
                }
            }
            #endif
        }
        .background {
            MyBackgroundColor()
        }
        .listStyle(.plain)
        .concentricMacWorkaround()
        .myNavigationTitle(LocalizedStringKey(subscription.title),
                           titleHidden: !showTitle
        )
        .toolbar {
            if !subscription.isArchived {
                RefreshToolbarContent(refreshOnlySubscription: subscription.persistentModelID)
            }
        }
        #if os(visionOS)
        .tint(nil)
        #endif
        .task(id: loadNewVideosTask) {
            if let task = loadNewVideosTask {
                await task.value
                isLoading = false
            }
        }
        .onAppear {
            handleOnAppear()
        }
        .onDisappear {
            handleOnDisappear()
        }
    }

    var imageUrl: URL? {
        if subscription.thumbnailUrl != nil {
            return subscription.thumbnailUrl
        }
        let fallbackVideo = subscription.videos?.first(where: {
            $0.isYtShort != true
        })
        return fallbackVideo?.thumbnailUrl
    }

    func handleOnAppear() {
        if navManager.tab == .library {
            navManager.lastLibrarySubscriptionId = subscription.persistentModelID
        }
    }

    func handleOnDisappear() {
        if subscription.isArchived && requiresUnsubscribe {
            let subId = subscription.persistentModelID
            _ = SubscriptionService.deleteSubscriptions([subId])
        }
        if navManager.tab == .library {
            navManager.lastLibrarySubscriptionId = nil
        }
    }

    func loadNewVideos() {
        if isLoading { return }
        isLoading = true
        let subId = subscription.persistentModelID
        loadNewVideosTask = Task {
            let task = VideoService.loadNewVideosInBg(
                subscriptionIds: [subId],
                fetchDurations: true
            )
            _ = try? await task.value
        }
    }
}

#Preview {
    let container = DataProvider.previewContainerFilled
    let fetch = FetchDescriptor<Subscription>()
    let subs = try? container.mainContext.fetch(fetch)
    let sub = subs?.first

    if let sub {
        return NavigationView {
            SubscriptionDetailView(subscription: sub)
                .previewEnvironments()
        }
    } else {
        return SubscriptionDetailView(subscription: Subscription.getDummy())
            .previewEnvironments()
    }
}
