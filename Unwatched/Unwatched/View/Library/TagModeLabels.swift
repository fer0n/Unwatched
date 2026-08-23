//
//  TagModeLabels.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

extension TagMode {
    var title: LocalizedStringKey {
        switch self {
        case .include: "tagModeInclude"
        case .exclude: "tagModeExclude"
        case .untagged: "tagModeUntagged"
        }
    }

    var helper: LocalizedStringKey {
        switch self {
        case .include: "tagModeIncludeHelper"
        case .exclude: "tagModeExcludeHelper"
        case .untagged: "tagModeUntaggedHelper"
        }
    }
}
