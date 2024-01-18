//
//  SettingsView.swift
//  Unwatched
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) var modelContext
    @AppStorage(Const.defaultEpisodePlacement) var defaultEpisodePlacement: VideoPlacement = .inbox
    @AppStorage(Const.playVideoFullscreen) var playVideoFullscreen: Bool = false
    @AppStorage(Const.autoplayVideos) var autoplayVideos: Bool = true

    let writeReviewUrl = URL(string: "https://apps.apple.com/app/id6444704240?action=write-review")!
    let emailUrl = URL(string: "mailto:scores.templates@gmail.com")!
    let githubUrl = URL(string: "https://github.com/fer0n/SplitBill")!
    // TODO: fix links

    var body: some View {
        VStack {
            List {
                Section {
                    Picker("newEpisodes", selection: $defaultEpisodePlacement) {
                        ForEach(VideoPlacement.allCases.filter { $0 != .defaultPlacement }, id: \.self) {
                            Text($0.description(defaultPlacement: ""))
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section {
                    Toggle(isOn: $playVideoFullscreen) {
                        Text("startVideosInFullscreen")
                    }
                    Toggle(isOn: $autoplayVideos) {
                        Text("autoplayVideos")
                    }
                }
                .tint(.teal)

                Section {
                    LinkItemView(destination: writeReviewUrl, label: "rateApp") {
                        Image(systemName: Const.rateAppSF)
                    }

                    LinkItemView(destination: emailUrl, label: "contact") {
                        Image(systemName: Const.contactMailSF)
                    }

                    LinkItemView(destination: githubUrl, label: "github") {
                        Image("github-logo")
                            .resizable()
                    }
                }

                Section {
                    let feedUrls = AsyncSharableUrls(getUrls: exportAllSubscriptions)
                    ShareLink(item: feedUrls, preview: SharePreview("exportSubscriptions"))
                }
            }
        }
        .toolbarBackground(Color.backgroundColor, for: .navigationBar)
        .navigationBarTitle("settings", displayMode: .inline)
        .tint(.myAccentColor)
    }

    func exportAllSubscriptions() async -> [(title: String, link: URL)] {
        let container = modelContext.container
        let result = try? await SubscriptionService.getAllFeedUrls(container)
        return result ?? []
    }
}

struct AsyncSharableUrls: Transferable {
    let getUrls: () async -> [(title: String, link: URL)]

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .plainText) { item in
            let urls = await item.getUrls()
            let textUrls = urls
                .map { "\($0.title)\n\($0.link.absoluteString)\n" }
                .joined(separator: "\n")
            print("textUrls", textUrls)
            let data = textUrls.data(using: .utf8)
            if let data = data {
                return data
            } else {
                fatalError()
            }
        }
    }
}

struct LinkItemView<Content: View>: View {
    let destination: URL
    let label: LocalizedStringKey
    let content: () -> Content

    var body: some View {
        Link(destination: destination) {
            HStack(spacing: 20) {
                content()
                    .frame(width: 24, height: 24)
                    .foregroundColor(.myAccentColor)
                Text(label)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                Image(systemName: Const.listItemChevronSF)
                    .foregroundColor(.myAccentColor)
            }
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(DataController.previewContainer)
        .environment(NavigationManager())
}
