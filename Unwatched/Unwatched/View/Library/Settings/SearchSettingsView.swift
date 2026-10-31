//
//  SearchSettingsView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct SearchSettingsView: View {
    @AppStorage(Const.showSearchRecommendations) var showSearchRecommendations: Bool = false
    @AppStorage(Const.showSearchYoutubeButton) var showSearchYoutubeButton: Bool = true
    @AppStorage(Const.autoFocusSearch) var autoFocusSearch: Bool = true
    @AppStorage(Const.showRecentSearches) var showRecentSearches: Bool = true
    @AppStorage(Const.playBrowserVideosInApp) var playBrowserVideosInApp: Bool = true

    var body: some View {
        ZStack {
            MyBackgroundColor()

            MyForm {
                MySection {
                    Toggle(isOn: $showSearchRecommendations) {
                        Text("showRecommendations")
                    }
                    if !showSearchRecommendations {
                        Toggle(isOn: $autoFocusSearch) {
                            Text("autoFocusSearch")
                        }
                        .transition(.opacity)
                    }
                    Toggle(isOn: $showRecentSearches) {
                        Text("showRecentSearches")
                    }
                    .onChange(of: showRecentSearches) { _, show in
                        if !show {
                            SearchVM.shared.clearRecentSearches()
                        }
                    }
                    #if os(iOS)
                    Toggle(isOn: $showSearchYoutubeButton) {
                        Text("showSearchYoutubeButton")
                    }
                    #endif
                }

                MySection("browserPlayback", footer: "$browserPlaybackFooter") {
                    Toggle(isOn: $playBrowserVideosInApp) {
                        Text("playBrowserVideosInApp")
                    }
                }
            }
            .animation(.default, value: showSearchRecommendations)
            .myNavigationTitle("search")
        }
    }
}

#Preview {
    SearchSettingsView()
}
