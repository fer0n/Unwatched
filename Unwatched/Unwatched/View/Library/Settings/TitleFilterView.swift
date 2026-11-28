//
//  TitleFilterView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct TitleFilterView: View {
    @CloudStorage(Const.filterVideoTitleText) var filterVideoTitleText: String = ""
    @CloudStorage(Const.allowOnMatch) var allowOnMatch: Bool = false

    var body: some View {
        Section {
            TitleFilterModePicker(allowOnMatch: $allowOnMatch)

            KeywordListEditor(text: $filterVideoTitleText)
        } header: {
            HStack {
                Text("videoTitleFilter")
                    .fontWeight(.semibold)
                PremiumIndicator()
            }
        } footer: {
            TitleFilterFooter(allowOnMatch: allowOnMatch)
        }
        .requiresPremium(filterVideoTitleText.isEmpty, feature: "titleFilter")
    }
}
