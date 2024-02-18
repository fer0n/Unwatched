//
//  BrowserView.swift
//  Unwatched
//

import SwiftUI
import WebKit
import TipKit

struct BrowserView: View, KeyboardReadable {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @Environment(RefreshManager.self) var refresher

    @State var browserManager = BrowserManager()
    @State var subscribeManager = SubscribeManager(isLoading: true)
    @State private var isKeyboardVisible = false
    @State var isDragOver = false
    @State var isLoading = false
    @State var isSuccess: Bool?
    @State var droppedUrls = [URL]()

    var ytBrowserTip = YtBrowserTip()
    var addButtonTip = AddButtonTip()

    var body: some View {
        let subscriptionText = browserManager.channelTextRepresentation

        GeometryReader { geometry in
            VStack {
                headerArea()

                ZStack {
                    YtBrowserWebView(browserManager: browserManager)
                    if !isKeyboardVisible {
                        VStack {
                            Spacer()
                            if subscriptionText == nil && browserManager.firstPageLoaded {
                                TipView(ytBrowserTip)
                                    .padding(.horizontal)
                                    .tint(.teal)
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
        .onChange(of: browserManager.channel?.userName) {
            subscribeManager.reset()
        }
        .onChange(of: browserManager.channel?.channelId) {
            subscribeManager.setIsSubscribed(browserManager.channel?.channelId)
        }
        .onReceive(keyboardPublisher) { newIsKeyboardVisible in
            isKeyboardVisible = newIsKeyboardVisible
        }
        .onAppear {
            subscribeManager.container = modelContext.container
        }
        .onDisappear {
            if subscribeManager.hasNewSubscriptions {
                refresher.refreshAll()
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
        .background(showDropArea ? .teal : .clear)
        .tint(Color.myAccentColor)
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
            let size: CGFloat = 30

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
                        .frame(width: size, height: size)
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
                        background: Color.myAccentColor,
                        foreground: Color.backgroundColor))
        .bold()
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
        print("handleUrlDrop inbox", urls)
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
        guard let channelId = browserManager.channel?.channelId,
              let isSubscribed = subscribeManager.isSubscribedSuccess else {
            print("handleAddSubButton without channelId/isSubscribed")
            return
        }

        if isSubscribed {
            subscribeManager.unsubscribe(channelId)
        } else {
            subscribeManager.addSubscription(channelId)
        }

    }
}

#Preview {
    BrowserView(isDragOver: true)
        .modelContainer(DataController.previewContainer)
        .environment(RefreshManager())
}
