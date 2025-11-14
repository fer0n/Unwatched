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
    var onSuccess: (() -> Void)?

    var body: some View {
        HStack {
            browseYoutubeButton
            Menu {
                SetupShareSheetAction()
                importSubscriptionsButton
                AddVideosButton()
                    .foregroundStyle(.primary)
            } label: {
                Image(systemName: "ellipsis")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .aspectRatio(1, contentMode: .fill)
            .buttonStyle(.borderedProminent)
        }
        .myTint()
        .fixedSize()
        .sheet(isPresented: $showImportSheet) {
            NavigationStack {
                ImportSubscriptionsView(onSuccess: {
                    showImportSheet = false
                    onSuccess?()
                })
                .myNavigationTitle("importSubscriptions")
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
            navManager.openUrlInApp(nil)
            Signal.log("Onboarding.BrowseYoutube", throttle: .weekly)
        } label: {
            Text("browser")
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
    }

    var importSubscriptionsButton: some View {
        Button {
            showImportSheet = true
            Signal.log("Onboarding.ImportSubscriptions", throttle: .weekly)
        } label: {
            Label("importFromYoutube", systemImage: "square.and.arrow.down.fill")
                .frame(maxWidth: .infinity)
        }
        .accessibilityLabel("importFromYoutube")
        .foregroundStyle(.primary)
        .buttonStyle(.bordered)
    }
}

#Preview {
    AddFeedsMenu()
        .environment(NavigationManager())
        .modelContainer(DataProvider.previewContainer)
}
