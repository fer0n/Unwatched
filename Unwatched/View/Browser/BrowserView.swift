//
//  BrowserView.swift
//  Unwatched
//

import SwiftUI
import WebKit
import TipKit
import OSLog

struct BrowserView: View, KeyboardReadable {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @Environment(RefreshManager.self) var refresher

    @AppStorage(Const.themeColor) var theme: ThemeColor = Color.defaultTheme

    @State var browserManager = BrowserManager()
    @State var subscribeManager = SubscribeManager(isLoading: true)
    @State private var isKeyboardVisible = false
    @State var isDragOver = false
    @State var isLoading = false
    @State var isSuccess: Bool?
    @State var droppedUrls = [URL]()
    @State var changeSubscriptionOf: ChannelInfo?

    var url: URL? = UrlService.youtubeStartPage

    var ytBrowserTip = YtBrowserTip()
    var addButtonTip = AddButtonTip()

    var body: some View {
        let subscriptionText = browserManager.channelTextRepresentation

        GeometryReader { geometry in
            VStack {
                headerArea()

                ZStack {
                    if let url = url {
                        YtBrowserWebView(url: url, browserManager: browserManager)
                    }
                    if !isKeyboardVisible {
                        VStack {
                            Spacer()
                            if subscriptionText == nil && browserManager.firstPageLoaded {
                                TipView(ytBrowserTip)
                                    .padding(.horizontal)
                            }
                            if let text = subscriptionText, !isKeyboardVisible {
                                addSubButton(text)
                                    .popoverTip(addButtonTip, arrowEdge: .bottom)
                                    .disabled(subscribeManager.isLoading)
                            }
                            Spacer()
                                .frame(height: (
                                        browserManager.isMobileVersion ? 60 : 0)
                                        + geometry.safeAreaInsets.bottom
                                )
                        }
                    }
                }
            }
            .ignoresSafeArea(edges: [.bottom])
        }
        .background(Color.youtubeWebBackground)
        .task(id: isSuccess) {
            await handleSuccessChange()
        }
        .task(id: droppedUrls) {
            guard !droppedUrls.isEmpty else {
                return
            }
            await handleUrlDrop(droppedUrls)
        }
        .task(id: browserManager.channel?.channelId) {
            subscribeManager.reset()
            await subscribeManager.setIsSubscribed(browserManager.channel)
        }
        .task(id: changeSubscriptionOf?.channelId) {
            await handleSubscriptionChange()
        }
        .onChange(of: browserManager.channel?.userName) {
            handleChannelInfoChanged(browserManager.channel)
        }
        .onReceive(keyboardPublisher) { newIsKeyboardVisible in
            isKeyboardVisible = newIsKeyboardVisible
        }
        .onAppear {
            subscribeManager.container = modelContext.container
            Task {
                await subscribeManager.setIsSubscribed(browserManager.channel)
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

    func headerArea() -> some View {
        let showDropArea = isDragOver || isLoading || isSuccess != nil

        return VStack {
            if showDropArea {
                Spacer()
                    .frame(height: 40)
            }
            if showDropArea {
                dropAreaContent
                    .frame(maxWidth: .infinity)
                Spacer()
                    .frame(height: 40)
            } else {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.down")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .padding(7)
                        .frame(maxWidth: .infinity)
                        .fontWeight(.semibold)
                }
            }
        }
        .background(showDropArea ? theme.color : .clear)
        .tint(.neutralAccentColor)
        .dropDestination(for: URL.self) { items, _ in
            droppedUrls = items
            return true
        } isTargeted: { targeted in
            withAnimation {
                isDragOver = targeted
            }
        }
        .sensoryFeedback(Const.sensoryFeedback, trigger: showDropArea)
    }

    var dropAreaContent: some View {
        ZStack {
            let size: CGFloat = 20

            if isLoading {
                ProgressView()
            } else if isSuccess == true {
                Image(systemName: "checkmark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            } else if isSuccess == false {
                Image(systemName: "xmark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            } else {
                VStack {
                    Image(systemName: Const.queueTagSF)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                    Text("dropVideoUrlsHere")
                        .fontWeight(.medium)
                }
            }
        }
        .foregroundStyle(.white)
    }

    func addSubButton(_ text: String) -> some View {
        Button(action: handleAddSubButton) {
            HStack {
                let systemName = subscribeManager.getSubscriptionSystemName()
                Image(systemName: systemName)
                    .contentTransition(.symbolEffect(.replace))
                Text(text)
            }
            .padding(10)
        }
        .buttonStyle(CapsuleButtonStyle(
                        background: Color.neutralAccentColor,
                        foreground: Color.backgroundColor))
        .bold()
    }

    func handleChannelInfoChanged(_ channelInfo: ChannelInfo?) {
        guard channelInfo?.channelId != nil,
              let channelId = channelInfo?.channelId else {
            Logger.log.info("no channel id after change")
            return
        }
        let container = modelContext.container
        _ = SubscriptionService.isSubscribed(channelId, updateChannelInfo: channelInfo, container: container)
    }

    func handleSuccessChange() async {
        if isSuccess != nil {
            do {
                try await Task.sleep(s: 1)
                withAnimation {
                    isSuccess = nil
                }
            } catch {}
        }
    }

    func handleUrlDrop(_ urls: [URL]) async {
        Logger.log.info("handleUrlDrop inbox \(urls)")
        withAnimation {
            isLoading = true
        }
        let container = modelContext.container
        let task = VideoService.addForeignUrls(urls, in: .queue, container: container)
        let success: ()? = try? await task.value
        withAnimation {
            self.isSuccess = success != nil
            self.isLoading = false
        }
    }

    func handleAddSubButton() {
        addButtonTip.invalidate(reason: .actionPerformed)
        ytBrowserTip.invalidate(reason: .actionPerformed)
        changeSubscriptionOf = browserManager.channel
    }

    func handleSubscriptionChange() async {
        guard let channelInfo = changeSubscriptionOf,
              let channelId = channelInfo.channelId,
              let isSubscribed = subscribeManager.isSubscribedSuccess else {
            Logger.log.info("handleAddSubButton without channelId/isSubscribed")
            return
        }
        if isSubscribed {
            await subscribeManager.unsubscribe(channelId)
        } else {
            await subscribeManager.addSubscription(channelInfo)
        }
    }
}

#Preview {
    BrowserView(isDragOver: true)
        .modelContainer(DataController.previewContainer)
        .environment(RefreshManager())
}
