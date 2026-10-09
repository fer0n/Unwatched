//
//  ChapterAutomationSettings.swift
//  Unwatched
//

import Foundation

enum ChapterGenerationMode: String, CaseIterable {
    case all
    case withoutChapters
    case selectedChannels
    case off

    var label: LocalizedStringResource {
        switch self {
        case .all: "chapterGenerationAll"
        case .withoutChapters: "chapterGenerationWithoutChapters"
        case .selectedChannels: "chapterGenerationSelectedChannels"
        case .off: "off"
        }
    }

    var channelDefaultLabel: LocalizedStringResource {
        self == .selectedChannels ? "off" : label
    }
}

enum ChapterAutomationScope: String, CaseIterable {
    case off
    case current
    case next

    var itemCount: Int {
        switch self {
        case .off: 0
        case .current: 1
        case .next: 2
        }
    }

    var label: LocalizedStringResource {
        switch self {
        case .off: "off"
        case .current: "chapterAutomationCurrent"
        case .next: "chapterAutomationNext"
        }
    }
}
