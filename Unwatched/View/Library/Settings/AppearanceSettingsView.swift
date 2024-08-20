//
//  AppearanceSettingsView.swift
//  Unwatched
//

import SwiftUI
import OSLog

struct AppearanceSettingsView: View {
    @AppStorage(Const.showTabBarLabels) var showTabBarLabels: Bool = true
    @AppStorage(Const.showTabBarBadge) var showTabBarBadge: Bool = true
    @AppStorage(Const.themeColor) var themeColor: ThemeColor = .teal
    @AppStorage(Const.browserAsTab) var browserAsTab: Bool = false
    @AppStorage(Const.sheetOpacity) var sheetOpacity: Bool = false
    @AppStorage(Const.lightPlayer) var lightPlayer: Bool = false

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
                    Toggle(isOn: $lightPlayer) {
                        Text("lightPlayer")
                    }
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

    @MainActor func setAppIcon(_ theme: ThemeColor) {
        UIApplication.shared.setAlternateIconName(theme.appIconName) { error in
            Logger.log.error("\(error)")
        }
    }
}

#Preview {
    AppearanceSettingsView()
}
