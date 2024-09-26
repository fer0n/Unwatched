//
//  AppearanceSettingsView.swift
//  Unwatched
//

import SwiftUI
import OSLog
import UnwatchedShared

struct AppearanceSettingsView: View {
    @AppStorage(Const.showTabBarLabels) var showTabBarLabels: Bool = true
    @AppStorage(Const.showTabBarBadge) var showTabBarBadge: Bool = true
    @AppStorage(Const.themeColor) var themeColor: ThemeColor = .teal
    @AppStorage(Const.browserAsTab) var browserAsTab: Bool = false
    @AppStorage(Const.sheetOpacity) var sheetOpacity: Bool = false
    @AppStorage(Const.videoListFormat) var videoListFormat: VideoListFormat = .compact

    @AppStorage(Const.lightModeTheme) var lightModeTheme = AppAppearance.unwatched
    @AppStorage(Const.darkModeTheme) var darkModeTheme = AppAppearance.dark

    @Environment(\.originalColorScheme) var originalColorScheme

    var body: some View {
        ZStack {
            Color.backgroundColor.ignoresSafeArea(.all)

            MyForm {
                MySection {
                    Toggle(isOn: $browserAsTab) {
                        Text("browserAsTab")
                    }
                }

                MySection {
                    Toggle(isOn: $showTabBarLabels) {
                        Text("showTabBarLabels")
                    }
                    Toggle(isOn: $showTabBarBadge) {
                        Text("showTabBarBadge")
                    }
                    Toggle(isOn: $sheetOpacity) {
                        Text("sheetOpacity")
                    }
                }

                MySection {
                    Picker("videoListFormat", selection: $videoListFormat) {
                        ForEach(VideoListFormat.allCases, id: \.self) {
                            Text($0.description)
                        }
                    }
                    .pickerStyle(.menu)
                }

                MySection(getAppearanceTitle(.light)) {
                    AppAppearanceSelection(selection: $lightModeTheme)
                        .environment(\.colorScheme, .light)
                }

                MySection(getAppearanceTitle(.dark)) {
                    AppAppearanceSelection(selection: $darkModeTheme)
                        .environment(\.colorScheme, .dark)
                }

                MySection("appColor") {
                    ForEach(ThemeColor.allCases, id: \.self) { theme in
                        Button {
                            themeColor = theme
                            setAppIcon(theme)
                        } label: {
                            HStack {
                                Label {
                                    Text(theme.description)
                                        .foregroundStyle(Color.neutralAccentColor)
                                } icon: {
                                    Image(systemName: theme == .blackWhite
                                            ? "circle.righthalf.filled"
                                            : "circle.fill")
                                        .foregroundStyle(theme.color)
                                        .background(Circle().fill(Color.backgroundColor).padding(3))
                                }
                                if theme == themeColor {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }
            .myNavigationTitle("appearance")
        }
    }

    func getAppearanceTitle(_ colorScheme: ColorScheme) -> LocalizedStringKey {
        if colorScheme == originalColorScheme {
            if colorScheme == .dark {
                return LocalizedStringKey("darkModeCurrent")
            } else {
                return LocalizedStringKey("lightModeCurrent")
            }
        } else {
            if colorScheme == .dark {
                return LocalizedStringKey("darkMode")
            } else {
                return LocalizedStringKey("lightMode")
            }
        }
    }

    @MainActor func setAppIcon(_ theme: ThemeColor) {
        UIApplication.shared.setAlternateIconName(theme.appIconName) { error in
            Logger.log.error("\(error)")
        }
    }
}

#Preview {
    AppearanceSettingsView()
}
