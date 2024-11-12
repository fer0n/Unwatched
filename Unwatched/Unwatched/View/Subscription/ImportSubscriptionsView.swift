//
//  ImportSubscriptionsView.swift
//  Unwatched
//

import SwiftUI
import OSLog
import UnwatchedShared

struct ImportSubscriptionsView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(RefreshManager.self) var refresher
    @Environment(NavigationManager.self) var navManager
    @AppStorage(Const.themeColor) var theme = ThemeColor()

    @State var showFileImporter = false
    @State var sendableSubs = [SendableSubscription]()
    @State var subStates = [SubscriptionState]()

    @State private var selection = Set<SendableSubscription>()
    @State var editMode = EditMode.active
    @State var isLoading = false
    @State var searchString = ""
    @State var loadSubStatesTask: Task<[SubscriptionState], Error>?

    var importButtonPadding = false
    var onSuccess: (() -> Void)?

    var body: some View {
        VStack {
            if sendableSubs.isEmpty {
                exportImportTutorial
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
                            .foregroundStyle(theme.color)
                        }
                    }

                    VStack {
                        Spacer()
                        Menu {
                            Button(action: startReplacingImport) {
                                Text("importReplaceSubscriptions")
                            }
                            Button(action: startAddImport) {
                                Text("importAddSubscriptions")
                            }
                        } label: {
                            Text(String(AttributedString(
                                localized: "importSubscriptions ^[\(selection.count) subscription](inflect: true)"
                            ).characters))
                        }

                        .padding(importButtonPadding ? 10 : 0)
                        .foregroundStyle(theme.contrastColor)
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .fileImporter(isPresented: $showFileImporter,
                      allowedContentTypes: [.plainText], onCompletion: handleFileImport)
        .onDisappear {
            if !subStates.isEmpty {
                onSuccess?()
                Task {
                    await refresher.refreshAll()
                }
            }
        }
        .task(id: loadSubStatesTask) {
            guard let task = loadSubStatesTask else {
                return
            }
            do {
                subStates = try await task.value
            } catch {
                Logger.log.error("error loading subStates: \(error)")
            }
            isLoading = false
        }
    }

    var exportImportTutorial: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 5) {
                Text("howToExportTitle")
                    .font(.title2)
                    .bold()

                Link(destination: UrlService.youtubeTakeoutUrl) {
                    Text("googleTakeout")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .foregroundStyle(theme.contrastColor)
                .padding(15)

                Text("howToExport2")
                    .padding(.bottom, 40)

                Text("howToImportTitle")
                    .font(.title2)
                    .bold()
                    .padding(.bottom, 10)

                Text("howToImport1")

                Button {
                    showFileImporter = true
                } label: {
                    Text("selectFile")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .foregroundStyle(theme.contrastColor)
                .padding(15)

                Text("howToImport2")
                Spacer()
            }
            .fontWeight(.regular)
            .tint(theme.color)
            .padding(.horizontal, 20)
        }
    }

    func startReplacingImport() {
        Logger.log.info("startReplacingImport")
        withAnimation {
            isLoading = true
        }

        SubscriptionService.softUnsubscribeAll(modelContext)
        startAddImport()
        SubscriptionService.cleanupArchivedSubscriptions()
    }

    func startAddImport() {
        Logger.log.info("startAddImport")
        withAnimation {
            isLoading = true
        }

        let container = modelContext.container
        let subs = Array(selection)
        loadSubStatesTask = Task {
            return try await SubscriptionService.addSubscriptions(
                from: subs)
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
            Logger.log.info("\(error.localizedDescription)")
        }
    }

    func readFile(_ file: URL) {
        do {
            let isSecureAccess = file.startAccessingSecurityScopedResource()
            let content = try String(contentsOf: file)
            let rows = content.components(separatedBy: "\n")
            parseRows(rows)
            if isSecureAccess {
                file.stopAccessingSecurityScopedResource()
            }
        } catch {
            Logger.log.error("Failed to read file: \(error)")
        }
    }

    func parseRows(_ rows: [String]) {
        let validRows = rows.dropFirst().filter { !$0.isEmpty }
        for row in validRows {
            if let sub = parseRow(row) {
                sendableSubs.append(sub)
            }
        }
        sendableSubs.sort(by: { $0.title < $1.title })
        selection = Set(sendableSubs)
    }

    func parseRow(_ row: String) -> SendableSubscription? {
        let columns = row.components(separatedBy: ",")
        Logger.log.info("columns \(columns)")
        guard columns.count >= 3 else {
            Logger.log.error("Invalid row: \(row)")
            return nil
        }
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
    .modelContainer(DataProvider.previewContainer)
    .environment(RefreshManager())
    .environment(NavigationManager())
}
