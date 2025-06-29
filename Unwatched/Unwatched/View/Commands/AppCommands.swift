//
//  HelpCommands.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct AppCommands: Commands {
    @Environment(\.openWindow) var openWindow
    @State var navManager = NavigationManager.shared

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Section {
                Link(destination: UrlService.writeReviewUrl) {
                    Text("rateUnwatched")
                }
            }
        }

        CommandGroup(after: .toolbar) {
            Section {
                Menu {
                    PlayerShortcut.goToQueue.render()
                    PlayerShortcut.goToInbox.render()
                    PlayerShortcut.goToLibrary.render()
                    if Const.browserAsTab.bool ?? false {
                        PlayerShortcut.goToBrowser.render()
                    }
                } label: {
                    Text("goToTab")
                }
            }

            Section {
                PlayerShortcut.refresh.render()
                PlayerShortcut.reloadPlayer.render()
            }

            Section {
                PlayerShortcut.hideControls.render()
                PlayerShortcut.toggleFullscreen.render()
            }
        }

        #if os(macOS)
        CommandGroup(after: .windowList) {
            Section {
                Button("browser") {
                    openWindow(id: Const.windowBrowser)
                }
                .keyboardShortcut("B", modifiers: .command)
            }
        }
        #endif

        CommandGroup(after: .importExport) {
            Section {
                Link(destination: UrlService.shareShortcutUrl) {
                    Text("setupShareSheetAction")
                }
            }

            Section {
                Button("importSubscriptions") {
                    openWindow(id: Const.windowImportSubs)
                }
            }

            Section {
                ExportSubscriptionsShareLink {
                    Text("exportSubscriptions")
                }
            }
        }

        CommandGroup(replacing: .help) {
            Button("unwatchedHelp") {
                openWindow(id: Const.windowHelp)
            }
            .keyboardShortcut("?", modifiers: .command)

            Link(destination: UrlService.issuesUrl) {
                Text("reportAnIssue")
            }

            Section {
                Link(destination: UrlService.getEmailUrl(body: Device.versionInfo)) {
                    Text("contactUs")
                }

                Link(destination: UrlService.githubUrl) {
                    Text("unwatchedOnGithub")
                }

                Link(destination: UrlService.mastodonUrl) {
                    Text("unwatchedOnMastodon")
                }

                Link(destination: UrlService.blueskyUrl) {
                    Text("unwatchedOnBluesky")
                }
            }
        }
    }
}
