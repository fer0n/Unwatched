//
//  VideoSettingsView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct GeneralSettingsView: View {
    @AppStorage(Const.browserDisplayMode) var browserDisplayMode: BrowserDisplayMode = .inApp
    @AppStorage(Const.defaultVideoPlacement) var defaultVideoPlacement: VideoPlacement = .inbox
    @AppStorage(Const.autoClearNew) var autoClearNew: Bool = false
    @AppStorage(Const.requireClearConfirmation) var requireClearConfirmation: Bool = true
    @AppStorage(Const.copyAppUrl) var copyAppUrl: Bool = false
    @AppStorage(Const.suggestVideos) var suggestVideos: Bool = false
    @AppStorage(Const.shareExtensionAction, store: .appGroup)
    var shareExtensionAction: ShareExtensionActionSetting = .askEveryTime

    var body: some View {
        ZStack {
            MyBackgroundColor()

            MyForm {
                MySection {
                    Picker("newVideos", selection: $defaultVideoPlacement) {
                        ForEach(VideoPlacement.allCases.filter { $0 != .defaultPlacement }, id: \.self) {
                            Text($0.description(defaultPlacement: ""))
                        }
                    }
                    .pickerStyle(.menu)
                }

                MySection(footer: "openLinksFooter") {
                    Picker("openLinks", selection: $browserDisplayMode) {
                        ForEach(BrowserDisplayMode.allCases, id: \.self) {
                            Text($0.description)
                        }
                    }
                    .pickerStyle(.menu)
                }

                MySection(footer: "autoClearNewFooter") {
                    Toggle(isOn: $autoClearNew) {
                        Text("autoClearNew")
                    }
                }

                MySection {
                    Toggle(isOn: $requireClearConfirmation) {
                        Text("requireClearConfirmation")
                    }
                }

                #if os(iOS)
                MySection(footer: "suggestVideosHelper") {
                    Toggle(isOn: $suggestVideos) {
                        Text("suggestVideos")
                    }
                }
                #endif

                MySection(footer: "shareExtensionActionFooter") {
                    Picker("shareExtensionAction", selection: $shareExtensionAction) {
                        ForEach(ShareExtensionActionSetting.allCases, id: \.self) {
                            Text($0.title)
                        }
                    }
                    .pickerStyle(.menu)
                }

                MySection(footer: "appUrlFooter") {
                    Toggle(isOn: $copyAppUrl) {
                        Text("appUrl")
                    }
                }
            }
            .myNavigationTitle("generalSettings")
        }
    }
}

#Preview {
    GeneralSettingsView()
}
