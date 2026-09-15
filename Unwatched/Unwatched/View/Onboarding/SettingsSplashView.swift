//
//  SettingsSplashView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct SettingsSplashView: View {
    @AppStorage(Const.settingsSplashShown) var settingsSplashShown = false

    @Environment(NavigationManager.self) var navManager

    @State private var page: SplashPage = .features

    private enum SplashPage: CaseIterable, Hashable, Sendable {
        case features
        case settings

        var title: LocalizedStringKey {
            switch self {
            case .features: return "settingsSplashFeaturesTitle"
            case .settings: return "settingsSplashSettingsTitle"
            }
        }

        var description: LocalizedStringKey? {
            switch self {
            case .features: return nil
            case .settings: return "settingsSplashSettingsDescription"
            }
        }
    }

    var body: some View {
        OnboardingPager(
            pages: SplashPage.allCases,
            page: $page,
            title: { $0.title },
            description: { $0.description },
            continueTitle: page == .settings ? "settingsSplashDone" : "onboardingContinue",
            onContinue: handleContinue
        ) {
            switch $0 {
            case .features: SplashFeaturesPage()
            case .settings: SplashSettingsPage()
            }
        }
    }

    func handleContinue() {
        switch page {
        case .features:
            withAnimation {
                page = .settings
            }
        case .settings:
            settingsSplashShown = true
            navManager.dismissSettingsSplash()
        }
    }
}

private struct SplashFeaturesPage: View {
    private struct Feature: Identifiable {
        let systemName: String
        let title: LocalizedStringKey
        let subtitle: LocalizedStringKey
        var premium = false

        var id: String { systemName }
    }

    private let features = [
        Feature(systemName: "antenna.radiowaves.left.and.right",
                title: "podcasts", subtitle: "settingsSplashPodcastsDescription"),
        Feature(systemName: "tag.fill",
                title: "tags", subtitle: "settingsSplashTagsDescription", premium: true),
        Feature(systemName: "applewatch",
                title: "settingsSplashWatchTitle", subtitle: "settingsSplashWatchDescription"),
        Feature(systemName: "sparkles.tv.fill",
                title: "settingsSplashNativePlayerTitle", subtitle: "settingsSplashNativePlayerDescription")
    ]

    private let smallerFeatures = [
        Feature(systemName: "rectangle.portrait.on.rectangle.portrait.angled.fill",
                title: "settingsSplashInboxCardsTitle", subtitle: "settingsSplashInboxCardsDescription"),
        Feature(systemName: "line.3.horizontal.decrease.circle.fill",
                title: "settingsSplashFiltersTitle", subtitle: "settingsSplashFiltersDescription", premium: true),
        Feature(systemName: "play.fill",
                title: "settingsSplashPlayerControlsTitle", subtitle: "settingsSplashPlayerControlsDescription"),
        Feature(systemName: "square.and.arrow.up.fill",
                title: "settingsSplashShareSheetTitle", subtitle: "settingsSplashShareSheetDescription"),
        Feature(systemName: "square.2.layers.3d.fill",
                title: "settingsSplashShortcutsTitle", subtitle: "settingsSplashShortcutsDescription")
    ]

    var body: some View {
        SplashCardList {
            SplashCard(
                systemName: "magnifyingglass",
                title: "settingsSplashSearchTitle",
                subtitle: "settingsSplashSearchDescription"
            ) {
                EmptyView()
            } footer: {
                BrowserAlternatives()
                    .padding(.leading, SplashCardLayout.textInset)
            }

            ForEach(features) { feature in
                SplashCard(
                    systemName: feature.systemName,
                    title: feature.title,
                    subtitle: feature.subtitle,
                    premium: feature.premium
                )
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(smallerFeatures, content: compactRow)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.insetBackgroundColor)
            )
        }
    }

    private func compactRow(_ feature: Feature) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: SplashCardLayout.iconSpacing) {
            Image(systemName: feature.systemName)
                .font(.subheadline)
                .foregroundStyle(.tint)
                .frame(width: SplashCardLayout.iconWidth)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(feature.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    if feature.premium {
                        PremiumIndicator()
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(feature.subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .containsPremium(feature.premium)
    }
}

private struct SplashSettingsPage: View {
    @AppStorage(Const.markWatchedOnEnded) var markWatchedOnEnded: Bool = true
    @AppStorage(Const.returnToQueue) var returnToQueue: Bool = true
    @CloudStorage(Const.autoDeleteWatchedVideos) var autoDeleteWatchedVideos: Int = 180
    @CloudStorage(Const.autoDeleteOrphanedVideos) var autoDeleteOrphanedVideos: Int = 30
    @CloudStorage(Const.autoDeleteInboxVideosLimit) var autoDeleteInboxVideosLimit: Int = 100

    var body: some View {
        SplashCardList {
            toggleCard(
                systemName: Const.watchedSF,
                title: "markWatchedOnEnded",
                subtitle: "markWatchedOnEndedHelper",
                isOn: $markWatchedOnEnded
            )

            toggleCard(
                systemName: "rectangle.stack.fill",
                title: "returnToQueue",
                subtitle: "settingsSplashReturnToQueueHelper",
                isOn: $returnToQueue
            )

            SplashCard(
                systemName: "archivebox.fill",
                title: "keepVideos",
                subtitle: "settingsSplashKeepMediaHelper"
            ) {
                EmptyView()
            } footer: {
                VStack(spacing: 4) {
                    SplashPickerRow(title: "autoDeleteWatchedVideos", selection: $autoDeleteWatchedVideos,
                                    options: AutoDeleteVideosView.dayOptions, label: AutoDeleteVideosView.dayLabel)
                    SplashPickerRow(title: "autoDeleteOrphanedVideos", selection: $autoDeleteOrphanedVideos,
                                    options: AutoDeleteVideosView.dayOptions, label: AutoDeleteVideosView.dayLabel)
                    SplashPickerRow(title: "autoDeleteInboxLimit", selection: $autoDeleteInboxVideosLimit,
                                    options: AutoDeleteVideosView.inboxLimitOptions,
                                    label: AutoDeleteVideosView.inboxLimitLabel)
                    Text("keepVideosSyncFooter")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 2)
                }
            }
        }
    }

    private func toggleCard(
        systemName: String,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        isOn: Binding<Bool>
    ) -> some View {
        SplashCard(systemName: systemName, title: title, subtitle: subtitle) {
            Toggle(title, isOn: isOn)
                .labelsHidden()
        }
    }
}

#Preview {
    Color.black
        .sheet(isPresented: .constant(true)) {
            SettingsSplashView()
        }
        .environment(NavigationManager())
}
