//
//  ChapterSkippingSettings.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct ChapterSkippingSettings: View {
    @CloudStorage(Const.skipChapterText) var skipChapterText: String = ""
    @PremiumCloudStorage(Const.autoSkipRecurringChapters) var autoSkipRecurringChapters = true
    @CloudStorage(Const.mergeSponsorBlockChapters) var mergeSponsorBlockChapters: Bool = false
    @AppStorage(Const.chapterGenerationMode) var generationMode = ChapterGenerationMode.off
    @CloudStorage(Const.sponsorSegmentSetting)
    var sponsorSegmentSetting: SponsorBlockSegmentSetting = SponsorBlockSegmentSetting.sponsorDefault
    @CloudStorage(Const.selfPromoSegmentSetting)
    var selfPromoSegmentSetting: SponsorBlockSegmentSetting = SponsorBlockSegmentSetting.selfPromoDefault

    var body: some View {
        MySection("skippingChapters", footer: "autoSkipRecurringChaptersFooter", showPremiumIndicator: true) {
            Toggle("autoSkipRecurringChapters", isOn: $autoSkipRecurringChapters)
        }
        .requiresPremium(feature: "skipRecurringChapters")

        MySection {
            NavigationLink(value: LibraryDestination.chapterFilter) {
                HStack {
                    Text("chapterFilter")
                    Spacer()
                    if !skipChapterText.isEmpty {
                        Text(verbatim: "\(skipChapterText.commaSeparatedKeywords.count)")
                            .foregroundStyle(.secondary)
                    }
                    PremiumIndicator()
                        .foregroundStyle(.secondary)
                }
            }
        }
        .containsPremium()
        .requiresPremium(skipChapterText.isEmpty, feature: "skipChapterText")

        MySection(footer: "skipSponsorSegmentsHelper") {
            SegmentSettingPicker(
                title: "sponsorSegments",
                selection: $sponsorSegmentSetting
            )
            SegmentSettingPicker(
                title: "selfPromoSegments",
                selection: $selfPromoSegmentSetting
            )
        }
        .disabled(!mergeSponsorBlockChapters && generationMode == .off)
    }
}

/// Picking "Show & Skip" asks for YouTube Premium before the selection changes.
private struct SegmentSettingPicker: View {
    @CloudStorage(Const.youtubePremium) var youtubePremium: Bool = false

    let title: LocalizedStringKey
    @Binding var selection: SponsorBlockSegmentSetting

    @State private var pendingSkip: PendingSkip?

    var body: some View {
        Picker(title, selection: Binding(
            get: { selection },
            set: { option in
                if option.skips && !youtubePremium {
                    pendingSkip = PendingSkip { selection = option }
                } else {
                    selection = option
                }
            }
        )) {
            ForEach(SponsorBlockSegmentSetting.allCases, id: \.self) { option in
                Text(option.description)
            }
        }
        .pickerStyle(.menu)
        .youtubePremiumConfirmation($pendingSkip)
    }
}

extension SponsorBlockSegmentSetting {
    var systemImage: String {
        switch self {
        case .nothing: return "eye.slash.fill"
        case .show: return "eye.fill"
        case .showAndSkip: return "forward.fill"
        @unknown default: return "questionmark"
        }
    }

    var description: String {
        switch self {
        case .nothing: return String(localized: "segmentSettingNothing")
        case .show: return String(localized: "segmentSettingShow")
        case .showAndSkip: return String(localized: "segmentSettingShowAndSkip")
        @unknown default: return "\(self.rawValue)"
        }
    }
}

#Preview {
    List {
        ChapterSkippingSettings()
    }
}
