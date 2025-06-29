//
//  TitleFilterView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct TitleFilterView: View {
    @CloudStorage(Const.filterVideoTitleText) var filterVideoTitleText: String = ""

    var body: some View {
        MySection(footer: "videoTitleFilterFooter") {
            TextField("keywords", text: $filterVideoTitleText)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .submitLabel(.done)
            #endif
        }
    }
}
