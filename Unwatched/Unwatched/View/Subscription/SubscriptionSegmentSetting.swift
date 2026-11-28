//
//  SubscriptionSegmentSetting.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

/// Which SponsorBlock category a per-channel override applies to.
enum SegmentCategory {
    case sponsor
    case selfPromo

    var label: LocalizedStringKey {
        self == .sponsor ? "sponsorSegments" : "selfPromoSegments"
    }

    var systemImage: String {
        self == .sponsor ? "dollarsign" : "megaphone.fill"
    }

    var setting: ReferenceWritableKeyPath<Subscription, SponsorBlockSegmentSetting?> {
        self == .sponsor ? \.sponsorSegmentSetting : \.selfPromoSegmentSetting
    }
}

/// Overrides the global setting for one segment category, for this channel only.
struct SubscriptionSegmentSetting: View {
    @CloudStorage(Const.sponsorSegmentSetting)
    var globalSponsor: SponsorBlockSegmentSetting = SponsorBlockSegmentSetting.sponsorDefault
    @CloudStorage(Const.selfPromoSegmentSetting)
    var globalSelfPromo: SponsorBlockSegmentSetting = SponsorBlockSegmentSetting.selfPromoDefault
    @CloudStorage(Const.youtubePremium) var youtubePremium: Bool = false

    var subscription: Subscription
    var category: SegmentCategory

    @State private var pendingSkip: PendingSkip?

    var body: some View {
        let selection = Binding(
            get: {
                subscription[keyPath: category.setting]
            }, set: { value in
                if value?.skips == true && !youtubePremium {
                    pendingSkip = PendingSkip { subscription[keyPath: category.setting] = value }
                } else {
                    subscription[keyPath: category.setting] = value
                }
            }
        )
        let followsDefault = selection.wrappedValue == nil

        CapsulePicker(
            selection: selection,
            options: options,
            label: {
                let text = $0?.description ?? String(localized: "defaultSegmentSetting \(globalSetting.description)")
                let img = $0?.systemImage ?? globalSetting.systemImage
                return (text, img)
            },
            menuLabel: category.label,
            hidesMenuValue: followsDefault
        )
        .requiresPremium(followsDefault, feature: "sponsorBlock")
        .youtubePremiumConfirmation($pendingSkip)
    }

    private var globalSetting: SponsorBlockSegmentSetting {
        category == .sponsor ? globalSponsor : globalSelfPromo
    }

    private var options: [SponsorBlockSegmentSetting?] {
        [nil] + SponsorBlockSegmentSetting.allCases.map { $0 }
    }
}
