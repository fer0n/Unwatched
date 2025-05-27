//
//  HelpView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct HelpView: View {

    var body: some View {
        ZStack {
            Color.backgroundColor.ignoresSafeArea(.all)

            MyForm {
                MySection(footer: "pleaseCheckFaq") {
                    Link(destination: UrlService.getEmailUrl(body: Device.versionInfo)) {
                        LibraryNavListItem("contactUs", systemName: Const.contactMailSF)
                    }
                }

                MySection("frequentlyAskedQuestions") {
                    FaqView()
                }
            }
        }
        .myNavigationTitle("emailAndFaq")
    }
}

#Preview {
    HelpView()
}
