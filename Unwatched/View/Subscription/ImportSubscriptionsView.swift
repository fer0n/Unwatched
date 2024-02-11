//
//  ImportSubscriptionsView.swift
//  Unwatched
//

import SwiftUI

struct ImportSubscriptionsView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(RefreshManager.self) var refresher

    @State var showFileImporter = false
    @State var sendableSubs = [SendableSubscription]()
    @State var subStates = [SubscriptionState]()

    @State private var selection = Set<SendableSubscription>()
    @State var editMode = EditMode.active
    @State var isLoading = false
    @State var searchString = ""

    var importButtonPadding = false

    var body: some View {
        VStack {
            if sendableSubs.isEmpty {
                Text("howToExportYoutubeSubscriptions")
                    .padding(10)
                if let url = UrlService.youtubeTakeoutUrl {
                    Link(destination: url) {
                        Text("youtubeTakeout")
                    }
                    .padding()
                }
                Spacer()
                    .frame(height: 50)
                Button {
                    showFileImporter = true
                } label: {
                    Text("selectFile")
                }
                .buttonStyle(.borderedProminent)
                Spacer()
            } else if isLoading {
                ProgressView {
                    Text("importing \(selection.count) subscriptions")
                }
            } else if !subStates.isEmpty {
                ScrollView {
                    VStack {
                        SubStateOverview(subStates: subStates,
                                         importSource: .csvImport)
                            .padding(.horizontal)
                    }
                }
            } else {
                ZStack {
                    List(selection: $selection) {

                        let filtered = sendableSubs.filter({
                            searchString.isEmpty
                                || $0.title.localizedStandardContains(searchString)
                        })
                        if !filtered.isEmpty {
                            ForEach(filtered, id: \.self) { sub in
                                Text(sub.title)
                            }
                            Spacer()
                                .frame(height: 50)
                                .listRowSeparator(.hidden)
                        }
                    }
                    .searchable(text: $searchString)
                    .listStyle(.plain)
                    .environment(\.editMode, $editMode)
                    .toolbar {
                        ToolbarItem {
                            Button(action: toggleSelection) {
                                Text(selection.count == sendableSubs.count
                                        ? "deselectAll"
                                        : "selectAll")
                            }
                        }
                    }

                    VStack {
                        Spacer()
                        Button(action: startImport) {
                            Text("importSelection")
                        }
                        .padding(importButtonPadding ? 10 : 0)
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .tint(.teal)
        .navigationTitle("importSubscriptions")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $showFileImporter,
                      allowedContentTypes: [.plainText], onCompletion: handleFileImport)
        .onDisappear {
            if !subStates.isEmpty {
                refresher.refreshAll()
            }
        }
    }

    func startImport() {
        print("startImport")
        withAnimation {
            isLoading = true
        }

        let container = modelContext.container
        let subs = Array(selection)
        Task {
            let res = try await SubscriptionService.addSubscriptions(
                from: subs,
                modelContainer: container)
            await MainActor.run {
                subStates = res
                isLoading = false
            }
        }
    }

    func toggleSelection() {
        if selection.count == sendableSubs.count {
            selection.removeAll()
        } else {
            selection = Set(sendableSubs)
        }
    }

    func handleFileImport(_ result: Result<URL, any Error>) {
        switch result {
        case .success(let file):
            readFile(file)
        case .failure(let error):
            print(error.localizedDescription)
        }
    }

    func readFile(_ file: URL) {
        do {
            let content = try String(contentsOf: file)
            let rows = content.components(separatedBy: "\n")
            parseRows(rows)
        } catch {
            print("Failed to read file: \(error)")
        }
    }

    func parseRows(_ rows: [String]) {
        let validRows = rows.dropFirst().filter { !$0.isEmpty }
        for row in validRows {
            let sub = parseRow(row)
            sendableSubs.append(sub)
        }
    }

    func parseRow(_ row: String) -> SendableSubscription {
        let columns = row.components(separatedBy: ",")
        print("columns", columns)
        let channelId = columns[0]
        // let channelUrl = columns[1] | not needed
        let channelTitle = columns[2]
        return SendableSubscription(title: channelTitle, youtubeChannelId: channelId)
    }

}

#Preview {
    ImportSubscriptionsView(
        //        sendableSubs: [
        //        SendableSubscription(title: "habie147", youtubeChannelId: "UC-FHoOa_jNSZy3IFctMEq2w"),
        //        SendableSubscription(title: "Broken Back", youtubeChannelId: "UC0q0O1XksvAATq_uH7IiEOA"),
        //        SendableSubscription(title: "CGPGrey2", youtubeChannelId: "UC127Qy2ulgASLYvW4AuHJZQ"),
        //        SendableSubscription(title: "CGP Grey", youtubeChannelId: "UC2C_jShtL725hvbm1arSV9w"),
        //        SendableSubscription(title: "Auto Focus", youtubeChannelId: "UC2J-0g_nxlwcD9JBK1eTleQ"),
        //        SendableSubscription(title: "LastWeekTonight", youtubeChannelId: "UC3XTzVzaHQEd30rQbuvCtTQ"),
        //        SendableSubscription(title: "habie147", youtubeChannelId: "UC-FHoOa_jNSZy3IFctMEq2w"),
        //        SendableSubscription(title: "Broken Back", youtubeChannelId: "UC0q0O1XksvAATq_uH7IiEOA"),
        //        SendableSubscription(title: "CGPGrey2", youtubeChannelId: "UC127Qy2ulgASLYvW4AuHJZQ"),
        //        SendableSubscription(title: "CGP Grey", youtubeChannelId: "UC2C_jShtL725hvbm1arSV9w"),
        //        SendableSubscription(title: "Auto Focus", youtubeChannelId: "UC2J-0g_nxlwcD9JBK1eTleQ"),
        //        SendableSubscription(title: "LastWeekTonight", youtubeChannelId: "UC3XTzVzaHQEd30rQbuvCtTQ"),
        //        SendableSubscription(title: "habie147", youtubeChannelId: "UC-FHoOa_jNSZy3IFctMEq2w"),
        //        SendableSubscription(title: "Broken Back", youtubeChannelId: "UC0q0O1XksvAATq_uH7IiEOA"),
        //        SendableSubscription(title: "CGPGrey2", youtubeChannelId: "UC127Qy2ulgASLYvW4AuHJZQ"),
        //        SendableSubscription(title: "CGP Grey", youtubeChannelId: "UC2C_jShtL725hvbm1arSV9w"),
        //        SendableSubscription(title: "Auto Focus", youtubeChannelId: "UC2J-0g_nxlwcD9JBK1eTleQ"),
        //        SendableSubscription(title: "LastWeekTonight", youtubeChannelId: "UC3XTzVzaHQEd30rQbuvCtTQ")
        //    ]
    )
    .modelContainer(DataController.previewContainer)
    .environment(RefreshManager())
}
