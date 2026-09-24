//
//  SponsorBlockSettingsView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared
import SwiftData

struct SponsorBlockSettingsView: View {
    @CloudStorage(Const.mergeSponsorBlockChapters) var mergeSponsorBlockChapters: Bool = false
    @CloudStorage(Const.youtubePremium) var youtubePremium: Bool = false
    @CloudStorage(Const.sponsorSegmentSetting)
    var sponsorSegmentSetting: SponsorBlockSegmentSetting = SponsorBlockSegmentSetting.sponsorDefault
    @CloudStorage(Const.selfPromoSegmentSetting)
    var selfPromoSegmentSetting: SponsorBlockSegmentSetting = SponsorBlockSegmentSetting.selfPromoDefault

    @Environment(\.modelContext) var modelContext

    @State var showAlert = false

    var body: some View {
        MySection("sponsorBlockSettings", footer: "sponsorBlockSettingsHelper") {
            Toggle(isOn: $mergeSponsorBlockChapters) {
                Text("sponsorBlockChapters")
            }
        }

        MySection(footer: "skipSponsorSegmentsHelper") {
            SegmentSettingPicker(
                title: "sponsorSegments",
                selection: $sponsorSegmentSetting,
                allowsSkipping: youtubePremium
            )
            SegmentSettingPicker(
                title: "selfPromoSegments",
                selection: $selfPromoSegmentSetting,
                allowsSkipping: youtubePremium
            )
        }
        .disabled(!mergeSponsorBlockChapters)

        MySection(footer: "considerGettingYoutubePremium") {
            HStack {
                Text("youtubePremium")
                Spacer()
                Image(systemName: "checkmark")
                    .opacity(youtubePremium ? 1 : 0)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if !youtubePremium {
                    showAlert = true
                } else {
                    youtubePremium = false
                    stopSkipping()
                }
            }
        }
        .confirmationDialog("youtubePremiumTitle",
                            isPresented: $showAlert,
                            titleVisibility: .visible,
                            actions: {
                                Button("youtubePremiumConfirm", role: .destructive) {
                                    youtubePremium = true
                                    showAlert = false
                                }
                                Button("youtubePremiumDecline") {
                                    showAlert = false
                                }
                                Button("cancel", role: .cancel) {}
                            },
                            message: { Text("considerGettingYoutubePremium") })
    }

    func stopSkipping() {
        if sponsorSegmentSetting.skips {
            sponsorSegmentSetting = .show
        }
        if selfPromoSegmentSetting.skips {
            selfPromoSegmentSetting = .show
        }
        SubscriptionService.stopSkippingSegments(modelContext)
    }
}

/// Looks like a Form picker row, but a `Picker` ignores `disabled` on its options and
/// "Show & Skip" has to stay visible while being unselectable without YouTube Premium.
private struct SegmentSettingPicker: View {
    @Environment(\.isEnabled) var isEnabled

    let title: LocalizedStringKey
    @Binding var selection: SponsorBlockSegmentSetting
    let allowsSkipping: Bool

    var body: some View {
        Menu {
            ForEach(SponsorBlockSegmentSetting.allCases, id: \.self) { option in
                Button {
                    selection = option
                } label: {
                    if selection == option {
                        Label(option.description, systemImage: Const.checkmarkSF)
                    } else {
                        Text(option.description)
                    }
                }
                .disabled(option.skips && !allowsSkipping)
            }
        } label: {
            HStack {
                Text(title)
                    .foregroundStyle(isEnabled ? Color.neutralAccentColor : Color.secondary)
                Spacer()
                Text(selection.description)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.footnote)
                    .fontWeight(.medium)
            }
        }
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

struct RightCheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            Image(systemName: "checkmark")
                .opacity(configuration.isOn ? 1 : 0)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation {
                configuration.isOn.toggle()
            }
        }
    }
}

#Preview {
    List {
        SponsorBlockSettingsView()
    }
}
