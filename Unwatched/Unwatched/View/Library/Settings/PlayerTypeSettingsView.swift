//
//  PlayerTypeSettingsView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct PlayerTypeSettingsView: View {
    @AppStorage(Const.playerType) var playerType: PlayerTypeSetting = .youtubeEmbedded
    @AppStorage(Const.showExperimentalPlayerTypes) var showExperimentalPlayerTypes: Bool = false

    var body: some View {
        ZStack {
            MyBackgroundColor(macOS: false)
            MyForm {
                optionSection(.youtubeEmbedded, footer: "playerTypeEmbeddedHelper")
                optionSection(.youtubeEmbeddedMinimal, footer: "playerTypeMinimalHelper")
                optionSection(.youtubeCustomUI, footer: "playerTypeCustomUIHelper")

                if showExperimentalPlayerTypes {
                    nativeSection
                }

                PlayerTypeComparisonTable(showNative: showExperimentalPlayerTypes)
            }
            .myNavigationTitle("playerType")
        }
    }

    func optionSection(_ type: PlayerTypeSetting, footer: LocalizedStringKey) -> some View {
        MySection(footer: footer) {
            HStack {
                Label(type.description, systemImage: type.systemImage)
                Spacer()
                if playerType == type {
                    Image(systemName: "checkmark")
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { playerType = type }
        }
    }

    var nativeSection: some View {
        MySection(footer: "playerTypeNativeHelper") {
            HStack {
                Label(PlayerTypeSetting.native.description, systemImage: PlayerTypeSetting.native.systemImage)
                Text("experimental")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.orange.opacity(0.15), in: Capsule())
                Spacer()
                if playerType == .native {
                    Image(systemName: "checkmark")
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { playerType = .native }
        }
    }
}

private struct PlayerTypeComparisonTable: View {
    let showNative: Bool

    struct Feature {
        let title: LocalizedStringKey
        let youtube: Bool
        let customUI: Bool
        let native: Bool
    }

    private let features: [Feature] = [
        Feature(title: "playerComparisonReliablePlayback", youtube: true, customUI: true, native: false),
        Feature(title: "playerComparisonHighSpeed", youtube: true, customUI: true, native: true),
        Feature(title: "playerComparisonManualQuality", youtube: true, customUI: false, native: true),
        Feature(title: "playerComparisonBackground", youtube: false, customUI: false, native: true),
        Feature(title: "playerComparisonStreamlinedOverlays", youtube: false, customUI: true, native: true)
    ]

    private let colWidth: CGFloat = 54

    var body: some View {
        MySection {
            VStack(alignment: .leading, spacing: 8) {
                headerRow
                Divider()
                ForEach(features.indices, id: \.self) { index in
                    featureRow(features[index])
                }
            }
            .padding(.vertical, 4)
        }
    }

    var headerRow: some View {
        HStack(spacing: 0) {
            Spacer()
            Text("playerTypeEmbedded")
                .frame(width: colWidth)
                .multilineTextAlignment(.center)
            Text("playerTypeCustomUIShort")
                .frame(width: colWidth)
                .multilineTextAlignment(.center)
            if showNative {
                Text("playerTypeNative")
                    .frame(width: colWidth)
                    .multilineTextAlignment(.center)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    func featureRow(_ feature: Feature) -> some View {
        HStack(spacing: 0) {
            Text(feature.title)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            comparisonIcon(feature.youtube).frame(width: colWidth)
            comparisonIcon(feature.customUI).frame(width: colWidth)
            if showNative {
                comparisonIcon(feature.native).frame(width: colWidth)
            }
        }
    }

    @ViewBuilder
    func comparisonIcon(_ supported: Bool) -> some View {
        Image(systemName: supported ? "checkmark.circle.fill" : "xmark.circle")
            .foregroundStyle(supported ? Color.green : Color.secondary)
    }
}

#Preview {
    PlayerTypeSettingsView()
}
