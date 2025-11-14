//
//  PrivacySettingsView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct PrivacySettingsView: View {
    @AppStorage(Const.analytics) var analytics = true
    @AppStorage(Const.useNoCookieUrl) var useNoCookieUrl: Bool = false

    var body: some View {
        ZStack {
            MyBackgroundColor(macOS: false)

            Form {
                Link(destination: UrlService.privacyUrl) {
                    Text("privacyPolicy")
                }
                .myListInsetBackground()

                MySection(footer: "useNoCookieUrlHelper") {
                    Toggle(isOn: $useNoCookieUrl) {
                        Text("useNoCookieUrl")
                    }
                    .onChange(of: useNoCookieUrl) { _, _ in
                        PlayerManager.reloadPlayer()
                    }
                }

                #if os(iOS)
                MySection(footer: "analyticsHelper") {
                    Toggle(isOn: $analytics) {
                        Text("anonymousAnalytics")
                    }
                    .signalToggle("Analytics", isOn: analytics)
                }
                #endif
            }
            .myNavigationTitle("privacyPolicy")
        }
    }
}

#Preview {
    PrivacySettingsView()
}
