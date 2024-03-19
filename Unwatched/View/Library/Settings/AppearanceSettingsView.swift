//
//  AppearanceSettingsView.swift
//  Unwatched
//

import SwiftUI

struct AppearanceSettingsView: View {
    @AppStorage(Const.showTabBarLabels) var showTabBarLabels: Bool = true
    @AppStorage(Const.showTabBarBadge) var showTabBarBadge: Bool = true
    @AppStorage(Const.themeColor) var themeColor: ThemeColor = .teal
    @AppStorage(Const.browserAsTab) var browserAsTab: Bool = false

    var body: some View {

        List {
            Toggle(isOn: $browserAsTab) {
                Text("browserAsTab")
            }

            Section {
                Toggle(isOn: $showTabBarLabels) {
                    Text("showTabBarLabels")
                }
                Toggle(isOn: $showTabBarBadge) {
                    Text("showTabBarBadge")
                }
            }

            Section("appColor") {
                ForEach(ThemeColor.allCases, id: \.self) { theme in
                    Button {
                        themeColor = theme
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
        .navigationTitle("appearance")
    }
}

#Preview {
    AppearanceSettingsView()
}
