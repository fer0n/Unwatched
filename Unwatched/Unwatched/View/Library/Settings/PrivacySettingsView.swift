//
//  PrivacySettingsView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct PrivacySettingsView: View {
    @AppStorage(Const.analytics) var analytics = true
    @AppStorage(Const.useNoCookieUrl) var useNoCookieUrl: Bool = false
    @AppStorage(Const.themeColor) var theme: ThemeColor = .defaultTheme

    var body: some View {
        ZStack {
            MyBackgroundColor()

            Form {
                Link(destination: UrlService.privacyUrl) {
                    Text("privacyPolicy")
                        .foregroundStyle(theme.color)
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
