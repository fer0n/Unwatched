//
//  PrivacySettingsView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct PrivacySettingsView: View {
    @AppStorage(Const.analytics) var analytics = true

    var body: some View {
        ZStack {
            Color.backgroundColor.ignoresSafeArea(.all)

            Form {
                Link(destination: UrlService.privacyUrl) {
                    Text("privacyPolicy")
                }
                .listRowBackground(Color.insetBackgroundColor)

                MySection(footer: "analyticsHelper") {
                    Toggle(isOn: $analytics) {
                        Text("anonymousAnalytics")
                    }
                    .signalToggle("Analytics", isOn: analytics)
                }
            }
            .myNavigationTitle("privacyPolicy")
        }
    }
}

#Preview {
    PrivacySettingsView()
}
