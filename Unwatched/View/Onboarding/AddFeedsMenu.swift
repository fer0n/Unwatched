//
//  AddFeedsMenu.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct DisappearingAddFeedsMenu: View {
    @Query(filter: #Predicate<Subscription> { $0.isArchived == false })
    var subscriptions: [Subscription]

    var body: some View {
        if subscriptions.isEmpty {
            AddFeedsMenu()
        }
    }
}

struct AddFeedsMenu: View {
    @Environment(NavigationManager.self) private var navManager
    @AppStorage(Const.themeColor) var theme: ThemeColor = Color.defaultTheme

    @State var showImportSheet = false
    var onSuccess: (() -> Void)?

    var body: some View {
        Menu {
            Button {
                showImportSheet = true
            } label: {
                Image(systemName: "square.and.arrow.down.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                Text("importFromYoutube")
            }
            Button {
                navManager.showMenu = true
                navManager.openUrlInApp(.youtubeStartPage)
            } label: {
                Label("browser", systemImage: Const.appBrowserSF)
            }
        } label: {
            Label("addFeeds", systemImage: "plus")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .sheet(isPresented: $showImportSheet) {
            NavigationStack {
                ImportSubscriptionsView(onSuccess: {
                    showImportSheet = false
                    onSuccess?()
                })
                .toolbar {
                    DismissToolbarButton {
                        showImportSheet = false
                    }
                }
                .tint(theme.color)
                .foregroundStyle(Color.neutralAccentColor)
            }
        }
    }
}
