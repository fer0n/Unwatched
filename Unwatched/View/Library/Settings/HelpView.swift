//
//  HelpView.swift
//  Unwatched
//

import SwiftUI

struct HelpView: View {

    var body: some View {

        ZStack {
            Color.backgroundColor.ignoresSafeArea(.all)

            MyForm {
                MySection(footer: "pleaseCheckFaq") {
                    Link(destination: UrlService.emailUrl) {
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
