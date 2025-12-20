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
    @AppStorage(Const.playBrowserVideosInApp) var playBrowserVideosInApp: Bool = false
    @Environment(ImageCacheManager.self) var cacheManager
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(RefreshManager.self) var refresher
    @Environment(\.dismissWindow) private var dismissWindow

    @Environment(BrowserManager.self) var browserManager
    @State var subscribeManager = SubscribeManager(isLoading: true)
    @State private var isKeyboardVisible = false

    var showHeader = true
    var safeArea = true

    var ytBrowserTip = YtBrowserTip()
    var addButtonTip = AddButtonTip()

    let size: Double = 20

    var body: some View {
        viewContent
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

    var viewContent: some View {
        #if os(visionOS)
        NavigationStack {
            browserContent
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        DismissSheetButton()
                    }
                    ToolbarItemGroup(placement: .navigation) {
                        Button {
                            browserManager.webView?.goBack()
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                        .disabled(browserManager.webView?.canGoBack != true)
                    }
                    ToolbarItemGroup(placement: .navigation) {
                        Button {
                            browserManager.webView?.goForward()
                        } label: {
                            Image(systemName: "chevron.right")
                        }
                        .disabled(browserManager.webView?.canGoForward != true)
                    }
                }
                .buttonBorderShape(.circle)
        }
        #else
        browserContent
        #endif
    }

    @ViewBuilder
    var browserContent: some View {
        @Bindable var browserManager = browserManager

        GeometryReader { geometry in
            VStack(spacing: 0) {
                if showHeader {
                    BrowserViewHeader()
                }

                ZStack {
                    YtBrowserWebView(browserManager: $browserManager,
                                     onDismiss: handleDismiss)
                        .id("\(playBrowserVideosInApp ? "inApp" : "external")")
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
                                        .apply {
                                            if #available(iOS 26, macOS 26, *) {
                                                $0.tipBackgroundInteraction(.enabled)
                                            } else {
                                                $0
                                            }
                                        }
                                        .disabled(subscribeManager.isLoading)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                } else {
                                    Spacer()
                                }

                                AddVideoButton(
                                    size: size,
                                    onDismiss: handleDismiss)
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
                                .frame(height: (enableBottomPadding ? 60 : 0)
                                        + (safeArea
                                            ? (max(geometry.safeAreaInsets.bottom, 15))
                                            : 0
                                        )
                                )
                        }
                    }
                }
                #if !os(visionOS)
                .clipShape(RoundedRectangle(cornerRadius: showHeader ? 15 : 0))
                #endif
            }
            .animation(.default, value: enableBottomPadding)
            .ignoresSafeArea(edges: safeArea ? [.bottom] : [])
        }
        #if !os(visionOS)
        .background(Color.youtubeWebBackground)
        #endif
        .appNotificationOverlay(topPadding: 20)
    }

    func handleDismiss() {
        #if os(macOS)
        dismissWindow(id: Const.windowBrowser)
        #endif
    }

    func addSubButton(_ text: String) -> some View {
        VStack {
            if let error = subscribeManager.errorMessage {
                Button {
                    subscribeManager.errorMessage = nil
                } label: {
                    Text(verbatim: error)
                }
                .buttonStyle(CapsuleButtonStyle(interactive: true))
            }
            Button(action: handleAddSubButton) {
                HStack {
                    let systemName = subscribeManager.getSubscriptionSystemName()
                    Image(systemName: systemName)
                        .contentTransition(.symbolEffect(.replace))
                        .symbolEffect(.pulse, isActive: subscribeManager.isLoading)
                    Text(text)
                        .lineLimit(2)
                }
                .padding(10)
            }
            .buttonStyle(CapsuleButtonStyle(interactive: true))
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
        Signal.log("Browser.AddSubscription", throttle: .weekly)
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
        #if os(macOS)
        return false
        #endif
        return horizontalSizeClass == .regular
    }

    var enableBottomPadding: Bool {
        browserManager.isMobileVersion && !browserManager.isVideoUrl
    }
}

#Preview {
    ZStack {}
        .sheet(isPresented: .constant(true)) {
            BrowserView(showHeader: false)
                .modelContainer(DataProvider.previewContainer)
                .environment(ImageCacheManager())
                .environment(RefreshManager())
                .environment(PlayerManager())
                .environment(NavigationManager())
                .environment(BrowserManager())
        }
}
