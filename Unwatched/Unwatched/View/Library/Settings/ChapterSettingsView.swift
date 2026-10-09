//
//  ChapterSettingsView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct ChapterSettingsView: View {
    @Environment(\.openURL) var openURL
    @CloudStorage(Const.installedChapterShortcut) var installedShortcut: String?
    @AppStorage(Const.chapterShortcutAutomation) var isAutomationEnabled = false
    @AppStorage(Const.chapterAutomationPodcasts) var podcastScope = ChapterAutomationScope.off
    @AppStorage(Const.chapterAutomationVideos) var videoScope = ChapterAutomationScope.off
    @AppStorage(Const.chapterGenerationMode) var mode = ChapterGenerationMode.off
    @AppStorage(Const.maxAutoTranscriptions) var maxTranscriptions = ChapterAutomation.liveTranscriptions
    @CloudStorage(Const.mergeSponsorBlockChapters) var mergeSponsorBlockChapters: Bool = false

    var body: some View {
        ZStack {
            MyBackgroundColor()

            MyForm {
                MySection("loadChapters", footer: "sponsorBlockSettingsHelper") {
                    Toggle("sponsorBlockChapters", isOn: $mergeSponsorBlockChapters)
                }

                generationSections

                automationSections

                ChapterSkippingSettings()
            }
            .animation(.default, value: isAutomationEnabled)
            .animation(.default, value: mode)
            .animation(.default, value: isShortcutSetUp)
            .myNavigationTitle("chapters")
        }
        .onChange(of: isAutomationEnabled) {
            if isAutomationEnabled {
                Task { await ChapterAutomation.requestNotificationPermission() }
                if mode == .off {
                    mode = .withoutChapters
                }
            }
            ChapterAutomation.scheduleRun()
        }
        .onChange(of: podcastScope) { ChapterAutomation.scheduleRun() }
        .onChange(of: videoScope) { ChapterAutomation.scheduleRun() }
        .onChange(of: mode) { ChapterAutomation.scheduleRun() }
        .onChange(of: maxTranscriptions) { ChapterAutomation.scheduleRun() }
    }

    @ViewBuilder
    private var automationSections: some View {
        MySection(footer: "shortcutAutomationFooter") {
            installShortcutButton

            Toggle("enableChapterShortcutAutomation", isOn: $isAutomationEnabled)
                .disabled(!isShortcutSetUp)
        }
        .requiresPremium()

        if isAutomationEnabled {
            MySection(footer: "chapterAutomationScopeFooter") {
                menuPicker("podcasts", selection: $podcastScope, options: ChapterAutomationScope.allCases) {
                    Text($0.label)
                }
                menuPicker("youtubeVideos", selection: $videoScope, options: [.off, .current]) {
                    Text($0.label)
                }
            }
            .disabled(!isShortcutSetUp)
            .requiresPremium()
        }
    }

    @ViewBuilder
    private var generationSections: some View {
        MySection("generateChapters", footer: generationFooter, showPremiumIndicator: true) {
            menuPicker("generateFor", selection: $mode, options: ChapterGenerationMode.allCases) {
                Text($0.label)
            }
        }
        .requiresPremium()

        #if os(iOS)
        if TranscriptService.canGenerateTranscript && mode != .off {
            MySection(footer: "maximumTranscriptionsFooter") {
                menuPicker(
                    "maximumTranscriptions",
                    selection: $maxTranscriptions,
                    options: ChapterAutomation.maxTranscriptionsOptions
                ) {
                    Text(verbatim: "\($0)")
                }
            }
            .requiresPremium()
        }
        #endif
    }

    private var generationFooter: LocalizedStringKey {
        TranscriptService.canGenerateTranscript ? "chapterGenerationTranscribeFooter" : "chapterGenerationFooter"
    }

    private var isShortcutSetUp: Bool {
        installedShortcut != nil
    }

    private var installShortcutButton: some View {
        Button(shortcutButtonTitle) {
            let url = UrlService.chapterAutomationShortcutUrl
            installedShortcut = url.absoluteString
            openURL(url)
        }
        .settingsListRow()
    }

    private var shortcutButtonTitle: LocalizedStringKey {
        guard isShortcutSetUp else { return "setupShortcutRequired" }
        return ChapterAutomation.isShortcutCurrent ? "setupShortcut" : "updateShortcut"
    }

    private func menuPicker<Value: Hashable>(
        _ title: LocalizedStringKey,
        selection: Binding<Value>,
        options: [Value],
        label: @escaping (Value) -> Text
    ) -> some View {
        Picker(title, selection: selection) {
            ForEach(options, id: \.self) { option in
                label(option).tag(option)
            }
        }
        .pickerStyle(.menu)
    }
}

#Preview {
    ChapterSettingsView()
        .previewEnvironments()
}
