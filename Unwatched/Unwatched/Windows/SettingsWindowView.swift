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
            settingsTab {
                GeneralSettingsView()
            }
            .tabItem {
                Label("generalSettings", systemImage: Const.settingsViewSF)
            }

            settingsTab {
                AppearanceSettingsView()
            }
            .tabItem {
                Label("appearance", systemImage: Const.appearanceSettingsSF)
            }

            settingsTab {
                PlaybackSettingsView()
            }
            .tabItem {
                Label("playback", systemImage: Const.playbackSettingsSF)
            }

            settingsTab {
                FilterSettingsView()
            }
            .tabItem {
                Label("filterSettings", systemImage: Const.filterSettingsSF)
            }

            settingsTab {
                UserDataSettingsView()
            }
            .tabItem {
                Label("userData", systemImage: Const.userDataSettingsSF)
            }

            settingsTab {
                DebugView()
            }
            .tabItem {
                Label("debug", systemImage: Const.debugSettingsSF)
            }

            settingsTab {
                PrivacySettingsView()
            }
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

    private func settingsTab<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            content()
                .settingsView()
                .padding(.vertical)
        }
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
