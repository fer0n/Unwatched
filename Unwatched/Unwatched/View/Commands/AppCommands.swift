//
//  HelpCommands.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct AppCommands: Commands {
    @Environment(\.openWindow) var openWindow

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Section {
                Link(destination: UrlService.writeReviewUrl) {
                    Text("rateUnwatched")
                }
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
                Link(destination: UrlService.getEmailUrl(body: HelpView.versionInfo)) {
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
