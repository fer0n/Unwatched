//
//  FilterSettingsView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct FilterSettingsView: View {
    @CloudStorage(Const.defaultShortsSetting) var defaultShortsSetting: ShortsSetting = .show
    @CloudStorage(Const.skipChapterText) var skipChapterText: String = ""
    @CloudStorage(Const.filterVideoTitleText) var filterVideoTitleText: String = ""

    @Environment(\.modelContext) var modelContext

    @State var shortsCount: Int?
    @State var showConfirm = false

    var body: some View {
        ZStack {
            Color.backgroundColor.ignoresSafeArea(.all)

            MyForm {
                MySection {
                    Text("settingsSync")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .foregroundStyle(.secondary)
                }

                MySection("videoFilter", footer: "shortsSettingsFooter") {
                    Picker("shortsSetting", selection: $defaultShortsSetting) {
                        ForEach(ShortsSetting.allCases.filter { $0 != .defaultSetting }, id: \.self) {
                            Text($0.description(defaultSetting: ""))
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: defaultShortsSetting) {
                        if defaultShortsSetting == .hide {
                            checkShortsInInbox()
                        }
                    }
                }

                MySection("chapterFilter", footer: "chapterFilterFooter") {
                    TextField("keywords", text: $skipChapterText)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .submitLabel(.done)
                    #endif
                }

                MySection("videoTitleFilter", footer: "videoTitleFilterFooter") {
                    TextField("keywords", text: $filterVideoTitleText)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .submitLabel(.done)
                    #endif
                }

                SponsorBlockSettingsView()
            }
            .confirmationDialog(
                "removeShortsFromInbox",
                isPresented: $showConfirm,
                titleVisibility: .visible,
                actions: {
                    Button("removeShortsFromInbox \(shortsCount ?? 0)", role: .destructive) {
                        VideoService.clearAllYtShortsFromInbox(modelContext)
                    }
                    Button("cancel", role: .cancel) { }
                }
            )
        }
        .myNavigationTitle("filterSettings")
    }

    func checkShortsInInbox() {
        Task {
            let task = VideoService.inboxShortsCount()
            if let count = await task.value, count > 0 {
                shortsCount = count
                showConfirm = true
            }
        }
    }
}

#Preview {
    FilterSettingsView()
}
