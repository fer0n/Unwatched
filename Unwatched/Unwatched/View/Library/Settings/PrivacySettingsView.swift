//
//  PrivacySettingsView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct PrivacySettingsView: View {
    /// App-group backed so `UnwatchedShareExtension` can read the same choice — see
    /// `AnalyticsSettings`/`Signal.migrateAnalyticsOptOutIfNeeded`.
    @AppStorage(Const.analytics, store: UserDefaults.appGroup) var analytics = true
    @AppStorage(Const.useNoCookieUrl) var useNoCookieUrl: Bool = false
    @AppStorage(Const.themeColor) var theme: ThemeColor = .defaultTheme

    var body: some View {
        ZStack {
            MyBackgroundColor()

            MyForm {
                Link(destination: UrlService.privacyUrl) {
                    Text("privacyPolicy")
                        .foregroundStyle(theme.color)
                }
                .settingsListRow()
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
                    .onChange(of: analytics) {
                        if analytics {
                            Signal.signalBool("Analytics", value: true)
                        } else {
                            Signal.handleOptOut()
                        }
                    }
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
