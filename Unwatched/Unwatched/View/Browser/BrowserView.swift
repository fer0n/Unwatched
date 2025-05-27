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
    @Environment(RefreshManager.self) var refresher

    @State var browserManager = BrowserManager()
    @State var subscribeManager = SubscribeManager(isLoading: true)
    @State private var isKeyboardVisible = false

    var url: Binding<BrowserUrl?> = .constant(nil)
    var startUrl: BrowserUrl?

    var showHeader = true
    var safeArea = true

    var ytBrowserTip = YtBrowserTip()
    var addButtonTip = AddButtonTip()

    let size: Double = 20

    var body: some View {
        GeometryReader { geometry in
            VStack {
                if showHeader {
                    BrowserViewHeader()
                }

                ZStack {
                    YtBrowserWebView(url: url,
                                     startUrl: startUrl,
                                     browserManager: $browserManager)
                    if !isKeyboardVisible {
                        VStack {
                            Spacer()

                            HStack(alignment: .center) {
                                Spacer()
                                    .frame(width: size, height: size)
                                    .padding(size)

                                if let text = subscriptionText, !isKeyboardVisible {
                                    addSubButton(text)
                                        .popoverTip(addButtonTip, arrowEdge: .bottom)
                                        .disabled(subscribeManager.isLoading)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                } else {
                                    Spacer()
                                }

                                AddVideoButton(browserManager: $browserManager, size: size)
                                    .padding(size)
                            }
                            .padding(.horizontal, supportsSplitView ? 110 : 0)
                            .frame(maxWidth: .infinity)

                            if subscriptionText == nil && browserManager.firstPageLoaded {
                                TipView(ytBrowserTip)
                                    .padding(.horizontal)
                                    #if os(macOS)
                                    .tipBackground(Color.automaticWhite)
                                #endif
                            }

                            Spacer()
                                .frame(height:
                                        (enableBottomPadding ? 60 : 0)
                                        + (max(geometry.safeAreaInsets.bottom, 15))
                                )
                        }
                    }
                }
            }
            .animation(.default, value: enableBottomPadding)
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
        #if os(iOS)
        .onReceive(keyboardPublisher) { newIsKeyboardVisible in
            isKeyboardVisible = newIsKeyboardVisible
        }
        #endif
        .onAppear {
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
            browserManager.stopPlayback()
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
                        .lineLimit(2)
                }
                .padding(10)
            }
            .buttonStyle(CapsuleButtonStyle())
            .bold()
        }
    }

    func handleSubscriptionInfoChanged(_ subscriptionInfo: SubscriptionInfo?) {
        Log.info("handleSubscriptionInfoChanged")
        guard let info = subscriptionInfo else {
            Log.info("no subscriptionInfo after change")
            return
        }
        let task = SubscriptionService.isSubscribed(channelId: info.channelId,
                                                    playlistId: info.playlistId,
                                                    updateSubscriptionInfo: info)
        clearCache(info, after: task)
    }

    func clearCache(_ info: SubscriptionInfo, after task: Task<(Bool), Never>) {
        Task {
            var sub: Subscription?

            if let channelId = info.channelId {
                _ = await task.value
                sub = SubscriptionService.getRegularChannel(channelId)
            } else if let userName = info.userName {
                sub = SubscriptionService.getRegularChannel(userName: userName)
            } else {
                Log.info("Neither channelId nor userName to update values")
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
        Log.info("handleSubscriptionChange")
        guard let isSubscribed = subscribeManager.isSubscribedSuccess,
              let subscriptionInfo = info else {
            Log.info("handleAddSubButton without info/isSubscribed")
            return
        }
        if isSubscribed {
            await subscribeManager.unsubscribe(subscriptionInfo)
        } else {
            await subscribeManager.addSubscription(subscriptionInfo)
        }
    }

    var subscriptionText: String? {
        browserManager.channelTextRepresentation
    }

    var supportsSplitView: Bool {
        return horizontalSizeClass == .regular
    }

    var enableBottomPadding: Bool {
        browserManager.isMobileVersion && !browserManager.isVideoUrl
    }
}

#Preview {
    BrowserView(startUrl: BrowserUrl.url("https://www.youtube.com/@BeardoBenjo"))
        .modelContainer(DataProvider.previewContainer)
        .environment(ImageCacheManager())
        .environment(RefreshManager())
        .environment(PlayerManager())
        .environment(NavigationManager())
}
