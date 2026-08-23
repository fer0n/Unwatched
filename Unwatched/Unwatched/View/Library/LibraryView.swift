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

    @Environment(NavigationManager.self) private var navManager

    @State var subManager = SubscribeManager()
    @State private var editedTag: TagEdit?
    var showCancelButton: Bool = false

    var body: some View {
        let topListItemId = NavigationManager.getScrollId("library")
        @Bindable var navManager = navManager

        NavigationStack(path: $navManager.presentedLibrary) {
            ZStack {
                MyBackgroundColor()

                List {
                    LibraryVideoSection()
                        .id(topListItemId)
                    LibraryTagSection(editedTag: $editedTag)
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
            // outside the list: anchored to a row, the sheet is torn down along with it
            // whenever a query re-emits, which drops the name field's focus
            .sheet(item: $editedTag) { edit in
                TagEditView(tag: edit.tag, isNew: edit.isNew)
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
            #if os(visionOS)
            .foregroundStyle(theme.contrastColor)
            #endif
        }
    }
}

#Preview {
    LibraryView()
        .previewEnvironments()
}
