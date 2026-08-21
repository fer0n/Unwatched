//
//  SettingsWindowView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct SettingsWindowView: View {
    @State var navTitleManager = NavigationTitleManager()
    @AppStorage(Const.themeColor) var theme: ThemeColor = .defaultTheme

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
                UserDataSettingsView()
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
        .frame(width: 700, height: 500)
        .myTint()
        #if os(macOS)
        // workaround: deprecated, but tint doesn't work on macOS
        .accentColor(theme.color)
        #endif
    }
}

#Preview {
    SettingsWindowView()
        .previewEnvironments()
}

extension View {
    func settingsView() -> some View {
        self
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
    }
}
