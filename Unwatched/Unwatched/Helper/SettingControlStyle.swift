//
//  SettingControlStyle.swift
//  Unwatched
//

import SwiftUI

enum SettingControlStyle {
    case capsule
    case chip
    case menuItem
}

extension EnvironmentValues {
    @Entry var settingControlStyle: SettingControlStyle = .capsule
    @Entry var settingIsActive: Bool?
    @Entry var chipContentColor: Color?
    @Entry var chipIconColor: Color?
    @Entry var compactSettingValues = false
    @Entry var premiumLockedFeature: String?
}
