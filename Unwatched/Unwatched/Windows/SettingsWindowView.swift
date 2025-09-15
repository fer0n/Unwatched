//
//  SettingsWindowView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct SettingsWindowView: View {
    @AppStorage(Const.themeColor) var theme = ThemeColor()
    @State var navTitleManager = NavigationTitleManager()

    var body: some View {
        TabView {
            GeneralSettingsView()
                .settingsView()
                .tabItem {
                    Label("generalSettings", systemImage: Const.settingsViewSF)
                }

            ScrollView {
                AppearanceSettingsView()
                    .settingsView()
                    .padding(.vertical)
            }
            .tabItem {
                Label("appearance", systemImage: Const.appearanceSettingsSF)
            }

            ScrollView {
                PlaybackSettingsView()
                    .settingsView()
                    .padding(.vertical)
            }
            .tabItem {
                Label("playback", systemImage: Const.playbackSettingsSF)
            }

            ScrollView {
                FilterSettingsView()
                    .settingsView()
                    .padding(.vertical)
            }
            .tabItem {
                Label("filterSettings", systemImage: Const.filterSettingsSF)
            }

            ScrollView {
                BackupView()
                    .settingsView()
                    .padding(.vertical)
            }
            .tabItem {
                Label("userData", systemImage: Const.userDataSettingsSF)
            }

            DebugView()
                .settingsView()
                .tabItem {
                    Label("debug", systemImage: Const.debugSettingsSF)
                }

            PrivacySettingsView()
                .settingsView()
                .tabItem {
                    Label("privacyPolicy", systemImage: "checkmark.shield.fill")
                }
        }
        .environment(navTitleManager)
        .background(Color.backgroundColor)
        .frame(width: 700, height: 500)
        .tint(theme.color)
        #if os(macOS)
        .toolbarBackground(Color.myBackgroundGray, for: .windowToolbar)
        // workaround: deprecated, but tint doesn't work on macOS
        .accentColor(theme.color)
        #endif
    }
}

#Preview {
    SettingsWindowView()
}

extension View {
    func settingsView() -> some View {
        self
            .frame(maxWidth: 600)
            .background(Color.backgroundColor)
            .frame(maxWidth: .infinity)
    }
}
