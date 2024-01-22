//
//  BrowserView.swift
//  Unwatched
//

import SwiftUI
import WebKit
import TipKit

struct BrowserView: View {
    @State var browserManager = BrowserManager()
    @State var subscribeManager = SubscribeManager(isLoading: true)
    @Environment(\.modelContext) var modelContext
    @Environment(RefreshManager.self) var refresher

    var ytBrowserTip = YtBrowserTip()
    var addButtonTip = AddButtonTip()

    var body: some View {
        let subscriptionText = browserManager.channelTextRepresentation

        GeometryReader { geometry in
            ZStack {
                YtBrowserWebView(fixSubManager: browserManager)
                VStack {
                    Spacer()
                    if subscriptionText == nil {
                        TipView(ytBrowserTip)
                            .padding(.horizontal)
                    }
                    if let text = subscriptionText {
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
                        .popoverTip(addButtonTip, arrowEdge: .bottom)
                        .disabled(subscribeManager.isLoading)
                    }
                    Spacer()
                        .frame(height: 60 + geometry.safeAreaInsets.bottom)
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
        .onAppear {
            subscribeManager.container = modelContext.container
        }
        .onDisappear {
            if subscribeManager.hasNewSubscriptions {
                refresher.refreshAll()
            }
        }
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
            subscribeManager.addNewSubscription(channelId)
        }

    }
}

#Preview {
    BrowserView()
        .modelContainer(DataController.previewContainer)
        .environment(RefreshManager())

}
