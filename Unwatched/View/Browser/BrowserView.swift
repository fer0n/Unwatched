//
//  BrowserView.swift
//  Unwatched
//

import SwiftUI
import WebKit
import TipKit

struct BrowserView: View, KeyboardReadable {
    @State var browserManager = BrowserManager()
    @State var subscribeManager = SubscribeManager(isLoading: true)
    @State private var isKeyboardVisible = false

    @Environment(\.modelContext) var modelContext
    @Environment(RefreshManager.self) var refresher

    var ytBrowserTip = YtBrowserTip()
    var addButtonTip = AddButtonTip()

    var body: some View {
        let subscriptionText = browserManager.channelTextRepresentation

        GeometryReader { geometry in
            ZStack {
                YtBrowserWebView(browserManager: browserManager)
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
            .ignoresSafeArea(.all)
        }
        .onChange(of: browserManager.userName) {
            subscribeManager.reset()
        }
        .onChange(of: browserManager.channelId) {
            subscribeManager.setIsSubscribed(browserManager.channelId)
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
        .buttonStyle(CapsuleButtonStyle())
    }

    func handleAddSubButton() {
        addButtonTip.invalidate(reason: .actionPerformed)
        ytBrowserTip.invalidate(reason: .actionPerformed)
        guard let channelId = browserManager.channelId,
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
    BrowserView()
        .modelContainer(DataController.previewContainer)
        .environment(RefreshManager())

}
