//
//  FilterSettingsView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct FilterSettingsView: View {
    @AppStorage(Const.defaultShortsSetting) var defaultShortsSetting: ShortsSetting = .show
    @AppStorage(Const.skipChapterText) var skipChapterText: String = ""

    var body: some View {
        ZStack {
            Color.backgroundColor.ignoresSafeArea(.all)

            MyForm {
                MySection("videoFilter", footer: "shortsSettingsFooter") {
                    Picker("shortsSetting", selection: $defaultShortsSetting) {
                        ForEach(ShortsSetting.allCases.filter { $0 != .defaultSetting }, id: \.self) {
                            Text($0.description(defaultSetting: ""))
                        }
                    }
                    .pickerStyle(.menu)
                }

                MySection("chapterFilter", footer: "chapterFilterFooter") {
                    TextField("skipChapterText", text: $skipChapterText)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .submitLabel(.done)
                }

                SponsorBlockSettingsView()
            }
        }
        .myNavigationTitle("filterSettings")
    }
}

#Preview {
    FilterSettingsView()
}
