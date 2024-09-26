//
//  BrowserView.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import WebKit
import TipKit
import OSLog
import UnwatchedShared

struct BrowserView: View, KeyboardReadable {
    @Environment(ImageCacheManager.self) var cacheManager
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    @State var browserManager = BrowserManager()
    @State var subscribeManager = SubscribeManager(isLoading: true)
    @State private var isKeyboardVisible = false

    var container: ModelContainer
    var refresher: RefreshManager
    // workaround: ^ when using @Environment with either of these
    // + this view inside a sheet, the app crashes on "My Mac (Designed for iPad)"

    var url: Binding<BrowserUrl?> = .constant(nil)
    var startUrl: BrowserUrl?

    var showHeader: Bool = true
    var safeArea: Bool = true

    var ytBrowserTip = YtBrowserTip()
    var addButtonTip = AddButtonTip()

    var body: some View {
        let subscriptionText = browserManager.channelTextRepresentation

        GeometryReader { geometry in
            VStack {
                if showHeader {
                    BrowserViewHeader()
                }

                ZStack {
                    YtBrowserWebView(url: url,
                                     startUrl: startUrl,
                                     browserManager: browserManager)
                    if !isKeyboardVisible {
                        VStack {
                            Spacer()
                            if subscriptionText == nil && browserManager.firstPageLoaded {
                                TipView(ytBrowserTip)
                                    .padding(.horizontal)
                            }

                            ZStack {
                                if let text = subscriptionText, !isKeyboardVisible {
                                    addSubButton(text)
                                        .popoverTip(addButtonTip, arrowEdge: .bottom)
                                        .disabled(subscribeManager.isLoading)
                                }

                                HStack {
                                    Spacer()
                                    AddVideoButton(container: container,
                                                   youtubeUrl: browserManager.videoUrl)
                                        .padding(20)
                                        .padding(.trailing, supportsSplitView ? 110 : 0)
                                }
                            }
                            .frame(maxWidth: .infinity)

                            Spacer()
                                .frame(height:
                                        (browserManager.isMobileVersion ? 60 : 0)
                                        + (safeArea ? geometry.safeAreaInsets.bottom : 0)
                                )
                        }
                    }
                }
            }
            .ignoresSafeArea(edges: safeArea ? [.bottom] : [])
        }
        .background(Color.youtubeWebBackground)
        .task(id: browserManager.info?.channelId) {
            subscribeManager.reset()
            await subscribeManager.setIsSubscribed(browserManager.info)
        }
        .task(id: browserManager.info?.playlistId) {
            subscribeManager.reset()
            handleSubscriptionInfoChanged(browserManager.info)
            await subscribeManager.setIsSubscribed(browserManager.info)
        }
        .onChange(of: browserManager.info?.userName) {
            handleSubscriptionInfoChanged(browserManager.info)
        }
        .onReceive(keyboardPublisher) { newIsKeyboardVisible in
            isKeyboardVisible = newIsKeyboardVisible
        }
        .onAppear {
            subscribeManager.container = container
            Task {
                await subscribeManager.setIsSubscribed(browserManager.info)
            }
        }
        .onDisappear {
            if subscribeManager.hasNewSubscriptions {
                Task {
                    await refresher.refreshAll()
                }
            }
        }
    }

    func addSubButton(_ text: String) -> some View {
        VStack {
            if let error = subscribeManager.errorMessage {
                Button {
                    subscribeManager.errorMessage = nil
                } label: {
                    Text(verbatim: error)
                }
                .buttonStyle(CapsuleButtonStyle())
            }
            Button(action: handleAddSubButton) {
                HStack {
                    let systemName = subscribeManager.getSubscriptionSystemName()
                    Image(systemName: systemName)
                        .contentTransition(.symbolEffect(.replace))
                    Text(text)
                }
                .padding(10)
            }
            .buttonStyle(CapsuleButtonStyle())
            .bold()
        }
    }

    func handleSubscriptionInfoChanged(_ subscriptionInfo: SubscriptionInfo?) {
        Logger.log.info("handleSubscriptionInfoChanged")
        guard let info = subscriptionInfo else {
            Logger.log.info("no subscriptionInfo after change")
            return
        }
        let container = container
        let task = SubscriptionService.isSubscribed(channelId: info.channelId,
                                                    playlistId: info.playlistId,
                                                    updateSubscriptionInfo: info,
                                                    container: container)
        clearCache(info, after: task)
    }

    func clearCache(_ info: SubscriptionInfo, after task: Task<(Bool), Never>) {
        let container = container
        Task {
            var sub: Subscription?

            if let channelId = info.channelId {
                _ = await task.value
                sub = SubscriptionService.getRegularChannel(channelId, container: container)
            } else if let userName = info.userName {
                sub = SubscriptionService.getRegularChannel(userName: userName,
                                                            container: container)
            } else {
                Logger.log.info("Neither channelId nor userName to update values")
            }

            if let url = sub?.thumbnailUrl?.absoluteString {
                self.cacheManager.clearCache(url)
            }
        }
    }

    func handleAddSubButton() {
        addButtonTip.invalidate(reason: .actionPerformed)
        ytBrowserTip.invalidate(reason: .actionPerformed)
        Task {
            await handleSubscriptionChange(browserManager.info)
        }
    }

    func handleSubscriptionChange(_ info: SubscriptionInfo?) async {
        Logger.log.info("handleSubscriptionChange")
        guard let isSubscribed = subscribeManager.isSubscribedSuccess,
              let subscriptionInfo = info else {
            Logger.log.info("handleAddSubButton without info/isSubscribed")
            return
        }
        if isSubscribed {
            await subscribeManager.unsubscribe(subscriptionInfo)
        } else {
            await subscribeManager.addSubscription(subscriptionInfo)
        }
    }

    var supportsSplitView: Bool {
        return horizontalSizeClass == .regular
    }
}

#Preview {
    BrowserView(container: DataController.previewContainer,
                refresher: RefreshManager(),
                startUrl: BrowserUrl.youtubeStartPage)
}
