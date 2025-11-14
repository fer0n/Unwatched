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
                MyBackgroundColor()

                List {
                    MySection(hasPadding: false) {
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
                .myNavigationTitle("library")
                .toolbar {
                    if showCancelButton {
                        DismissToolbarButton()
                    }
                    #if os(iOS) || os(visionOS)
                    settingsToolbarButton
                    #endif
                    RefreshToolbarContent()
                }
            }
            .myTint()
            .libraryDestination()
        }
        .tint(navManager.lastLibrarySubscriptionId == nil ? theme.color : .neutralAccentColor)
    }

    var settingsToolbarButton: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            NavigationLink(value: LibraryDestination.settings) {
                Image(systemName: Const.settingsViewSF)
                    .fontWeight(.bold)
                    .accessibilityLabel("settings")
            }
        }
    }
}

#Preview {
    LibraryView()
        .testEnvironments()
}
