//
//  AppearanceSettingsView.swift
//  Unwatched
//

import SwiftUI

struct AppearanceSettingsView: View {
    @AppStorage(Const.showTabBarLabels) var showTabBarLabels: Bool = true
    @AppStorage(Const.showNewInboxBadge) var showNewInboxBadge: Bool = true
    @AppStorage(Const.themeColor) var themeColor: ThemeColor = .teal

    var body: some View {
        List {
            Toggle(isOn: $showTabBarLabels) {
                Text("showTabBarLabels")
            }
            Toggle(isOn: $showNewInboxBadge) {
                Text("showNewInboxBadge")
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
