//
//  AppearanceSettingsView.swift
//  Unwatched
//

import SwiftUI

struct AppearanceSettingsView: View {
    @AppStorage(Const.showTabBarLabels) var showTabBarLabels: Bool = true
    @AppStorage(Const.showNewInboxBadge) var showNewInboxBadge: Bool = true

    var body: some View {
        List {
            Toggle(isOn: $showTabBarLabels) {
                Text("showTabBarLabels")
            }
            Toggle(isOn: $showNewInboxBadge) {
                Text("showNewInboxBadge")
            }
        }
        .navigationTitle("appearance")
    }
}

#Preview {
    AppearanceSettingsView()
}
