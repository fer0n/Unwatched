//
//  LibraryView.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import OSLog
import UnwatchedShared

struct LibraryView: View {
    @AppStorage(Const.themeColor) var theme = ThemeColor()
    @AppStorage(Const.browserAsTab) var browserAsTab: Bool = false

    @Environment(NavigationManager.self) private var navManager

    @State var subManager = SubscribeManager()
    var showCancelButton: Bool = false

    var body: some View {
        let topListItemId = NavigationManager.getScrollId("library")
        @Bindable var navManager = navManager

        NavigationStack(path: $navManager.presentedLibrary) {
            ZStack {
                Color.backgroundColor.ignoresSafeArea(.all)

                List {
                    MySection {
                        AddToLibraryView(subManager: $subManager,
                                         showBrowser: !browserAsTab)
                            .id(topListItemId)
                    }
                    LibraryVideoSection()
                    SubscriptionListSection(subManager: $subManager,
                                            theme: theme)
                }
                .scrollContentBackground(.hidden)
                .onAppear {
                    navManager.topListItemId = topListItemId
                }
                .myNavigationTitle("library", showBack: false)
                .libraryDestination()
                .toolbar {
                    if showCancelButton {
                        DismissToolbarButton()
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        NavigationLink(value: LibraryDestination.settings) {
                            Image(systemName: Const.settingsViewSF)
                                .fontWeight(.bold)
                                .accessibilityLabel("settings")
                        }
                    }
                    RefreshToolbarButton()
                }
            }
            .tint(theme.color)
        }
        .tint(navManager.lastLibrarySubscriptionId == nil ? theme.color : .neutralAccentColor)
    }
}

#Preview {
    LibraryView()
        .modelContainer(DataController.previewContainer)
        .environment(NavigationManager())
        .environment(PlayerManager())
        .environment(RefreshManager())
        .environment(ImageCacheManager())
}
