//
//  HelpView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct HelpView: View {
    @State private var showReportIssue = false

    var body: some View {
        ZStack {
            MyBackgroundColor(macOS: false)

            MyForm {
                MySection(footer: "pleaseCheckFaq") {
                    Button {
                        showReportIssue = true
                    } label: {
                        LibraryNavListItem("reportIssue", systemName: "exclamationmark.bubble.fill")
                    }
                    .settingsListRow()
                    Link(destination: UrlService.getEmailUrl(body: Device.versionInfo)) {
                        LibraryNavListItem("contactUs", systemName: Const.contactMailSF)
                    }
                    .visionForegroundColor()
                    .settingsListRow()
                }

                MySection("frequentlyAskedQuestions") {
                    FaqView()
                }
            }
        }
        .myNavigationTitle("feedbackAndFaq")
        .sheet(isPresented: $showReportIssue) {
            ReportIssueView()
        }
    }
}

#Preview {
    HelpView()
}
