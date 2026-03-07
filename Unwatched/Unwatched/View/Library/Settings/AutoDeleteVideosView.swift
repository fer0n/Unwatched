//
//  AutoDeleteVideosView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct AutoDeleteVideosView: View {
    @AppStorage(Const.autoDeleteWatchedVideos) var autoDeleteWatchedVideos: Int = 0
    @AppStorage(Const.autoDeleteOrphanedVideos) var autoDeleteOrphanedVideos: Int = 0
    @AppStorage(Const.autoDeleteInboxVideosLimit) var autoDeleteInboxVideosLimit: Int = 0

    static let dayOptions = [0, 1, 3, 7, 30, 90, 180, 270, 365]
    static let inboxLimitOptions = [0, 20, 50, 100, 500]

    var body: some View {
        MySection("keepVideos") {
            Picker("autoDeleteWatchedVideos", selection: $autoDeleteWatchedVideos) {
                ForEach(Self.dayOptions, id: \.self) { days in
                    Text(dayLabel(days)).tag(days)
                }
            }
            .pickerStyle(.menu)

            Picker("autoDeleteOrphanedVideos", selection: $autoDeleteOrphanedVideos) {
                ForEach(Self.dayOptions, id: \.self) { days in
                    Text(dayLabel(days)).tag(days)
                }
            }
            .pickerStyle(.menu)

            Picker("autoDeleteInboxLimit", selection: $autoDeleteInboxVideosLimit) {
                ForEach(Self.inboxLimitOptions, id: \.self) { limit in
                    Text(inboxLimitLabel(limit)).tag(limit)
                }
            }
            .pickerStyle(.menu)
        }
    }

    func dayLabel(_ days: Int) -> LocalizedStringKey {
        switch days {
        case 0: return "never"
        case 1: return "oneDay"
        case 3: return "threeDays"
        case 7: return "oneWeek"
        case 30: return "oneMonth"
        case 90: return "threeMonths"
        case 180: return "sixMonths"
        case 270: return "nineMonths"
        case 365: return "oneYear"
        default: return LocalizedStringKey("\(days)")
        }
    }

    func inboxLimitLabel(_ limit: Int) -> LocalizedStringKey {
        limit == 0 ? "unlimited" : LocalizedStringKey("\(limit)")
    }
}
