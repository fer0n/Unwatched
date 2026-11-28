//
//  AutoDeleteVideosView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct AutoDeleteVideosView: View {
    @CloudStorage(Const.autoDeleteWatchedVideos) var autoDeleteWatchedVideos: Int = 180
    @CloudStorage(Const.autoDeleteOrphanedVideos) var autoDeleteOrphanedVideos: Int = 30

    static let dayOptions = [0, 1, 3, 7, 30, 90, 180, 270, 365]

    var body: some View {
        MySection("keepVideos", footer: "keepVideosSyncFooter") {
            Picker("autoDeleteWatchedVideos", selection: $autoDeleteWatchedVideos) {
                ForEach(Self.dayOptions, id: \.self) { days in
                    Text(Self.dayLabel(days)).tag(days)
                }
            }
            .pickerStyle(.menu)

            Picker("autoDeleteOrphanedVideos", selection: $autoDeleteOrphanedVideos) {
                ForEach(Self.dayOptions, id: \.self) { days in
                    Text(Self.dayLabel(days)).tag(days)
                }
            }
            .pickerStyle(.menu)
        }
    }

    static func dayLabel(_ days: Int) -> LocalizedStringKey {
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
}
