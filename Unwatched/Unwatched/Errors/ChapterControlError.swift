//
//  ChapterControlError.swift
//  Unwatched
//

import SwiftUI

enum ChapterControlError: Error, CustomLocalizedStringResourceConvertible {
    case noNextChapter
    case noPreviousChapter

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noNextChapter:
            return "noNextChapterError"
        case .noPreviousChapter:
            return "noPreviousChapterError"
        }
    }
}
