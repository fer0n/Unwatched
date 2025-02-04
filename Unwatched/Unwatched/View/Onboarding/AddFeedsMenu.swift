//
//  AddFeedsMenu.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

struct AddFeedsMenu: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(NavigationManager.self) private var navManager
    @AppStorage(Const.themeColor) var theme = ThemeColor()

    @State var showImportSheet = false
    var includeShareSheet = false
    var onSuccess: (() -> Void)?

    var body: some View {
        HStack {
            browseYoutubeButton
            Menu {
                if includeShareSheet {
                    SetupShareSheetAction()
                }
                importSubscriptionsButton
                AddVideosButton()
                    .tint(theme.color)
                    .foregroundStyle(theme.contrastColor)
            } label: {
                Image(systemName: "ellipsis")
                    .frame(maxHeight: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .fixedSize()
        .sheet(isPresented: $showImportSheet) {
            NavigationStack {
                ImportSubscriptionsView(onSuccess: {
                    showImportSheet = false
                    onSuccess?()
                })
                .myNavigationTitle("importSubscriptions", showBack: false)
                .toolbar {
                    DismissToolbarButton {
                        showImportSheet = false
                    }
                }
                .tint(theme.darkColor)
                .foregroundStyle(Color.neutralAccentColor)
            }
            .environment(\.colorScheme, colorScheme)
        }
    }

    var browseYoutubeButton: some View {
        Button {
            navManager.showMenu = true
            navManager.openUrlInApp(.youtubeStartPage)
        } label: {
            Text("browser")
        }
        .buttonStyle(.borderedProminent)
    }

    var importSubscriptionsButton: some View {
        Button {
            showImportSheet = true
        } label: {
            Label("importFromYoutube", systemImage: "square.and.arrow.down.fill")
                .frame(maxWidth: .infinity)
        }
        .accessibilityLabel("importFromYoutube")
        .tint(theme.color)
        .foregroundStyle(theme.contrastColor)
        .buttonStyle(.bordered)
    }
}

#Preview {
    AddFeedsMenu()
        .environment(NavigationManager())
        .modelContainer(DataProvider.previewContainer)
}
