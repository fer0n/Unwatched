//
//  ChapterFilterView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct ChapterFilterView: View {
    @CloudStorage(Const.skipChapterText) var skipChapterText: String = ""

    var body: some View {
        ZStack {
            MyBackgroundColor()

            MyForm {
                MySection(footer: "chapterFilterFooter") {
                    KeywordListEditor(text: $skipChapterText)
                }
                .requiresPremium(skipChapterText.isEmpty, feature: "skipChapterText")
            }
            .myNavigationTitle("chapterFilter")
        }
    }
}
