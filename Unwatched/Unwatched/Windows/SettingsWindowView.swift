//
//  SettingsWindowView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

enum SettingsWindowTab {
    case general, appearance, playback, mediaFilter, chapters, userData, debug, privacy
}

struct SettingsWindowView: View {
    @AppStorage(Const.themeColor) var theme: ThemeColor = .defaultTheme
    @Environment(NavigationManager.self) var navManager

    var body: some View {
        @Bindable var navManager = navManager
        TabView(selection: $navManager.settingsWindowTab) {
            settingsTab(.general, "generalSettings", systemImage: Const.settingsViewSF) {
                GeneralSettingsView()
            }
            settingsTab(.appearance, "appearance", systemImage: Const.appearanceSettingsSF) {
                AppearanceSettingsView()
            }
            settingsTab(.playback, "playback", systemImage: Const.playbackSettingsSF) {
                PlaybackSettingsView()
            }
            settingsTab(.mediaFilter, "mediaFilter", systemImage: Const.filterSettingsSF) {
                FilterSettingsView()
            }
            settingsTab(.chapters, "chapters", systemImage: Const.chaptersSF) {
                ChapterSettingsView()
            }
            settingsTab(.userData, "userData", systemImage: Const.userDataSettingsSF) {
                UserDataSettingsView()
            }
            settingsTab(.debug, "debug", systemImage: Const.debugSettingsSF) {
                DebugView()
            }
            settingsTab(.privacy, "privacyPolicy", systemImage: "checkmark.shield.fill") {
                PrivacySettingsView()
            }
        }
        .frame(width: 700, height: 500)
        .myTint()
        #if os(macOS)
        // workaround: deprecated, but tint doesn't work on macOS
        .accentColor(theme.color)
        #endif
    }

    private func settingsTab<Content: View>(
        _ tab: SettingsWindowTab,
        _ title: LocalizedStringKey,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ScrollView {
            content()
                .settingsView()
                .padding(.vertical)
        }
        .tabItem {
            Label(title, systemImage: systemImage)
        }
        .tag(tab)
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
