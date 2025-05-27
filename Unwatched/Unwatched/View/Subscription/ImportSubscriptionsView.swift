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
    @AppStorage(Const.themeColor) var theme = ThemeColor()

    @State var showFileImporter = false
    @State var sendableSubs = [SendableSubscription]()
    @State var subStates = [SubscriptionState]()

    @State private var selection = Set<SendableSubscription>()
    #if os(iOS)
    @State var editMode = EditMode.active
    #else
    @State var editMode = NSTableView.SelectionHighlightStyle.regular
    #endif
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
                    .listRowBackground(Color.backgroundColor)
                    .searchable(text: $searchString)
                    .listStyle(.plain)
                    #if os(iOS)
                    .environment(\.editMode, $editMode)
                    // macOS doesn't need explicit edit mode for multi-selection
                    #endif
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
                        #if os(iOS)
                        .buttonStyle(.borderedProminent)
                        #else
                        .buttonStyle(MyButtonStyle())
                        .padding()
                        #endif
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 600)
        #endif
        .background {
            Color.backgroundColor.ignoresSafeArea(.all)
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
                Log.error("error loading subStates: \(error)")
            }
            isLoading = false
        }
    }

    var exportImportTutorial: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 5) {
                Text("howToExportTitle")
                    .font(.title3)
                    .bold()
                    .frame(maxWidth: .infinity, alignment: .center)

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
                    .font(.title3)
                    .bold()
                    .frame(maxWidth: .infinity, alignment: .center)
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
        Log.info("startReplacingImport")
        withAnimation {
            isLoading = true
        }

        SubscriptionService.softUnsubscribeAll(modelContext)
        startAddImport()
        SubscriptionService.cleanupArchivedSubscriptions()
    }

    func startAddImport() {
        Log.info("startAddImport")
        withAnimation {
            isLoading = true
        }

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
            Log.info("\(error.localizedDescription)")
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
            Log.error("Failed to read file: \(error)")
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
        Log.info("columns \(columns)")
        guard columns.count >= 3 else {
            Log.error("Invalid row: \(row)")
            return nil
        }
        let channelId = columns[0]
        // let channelUrl = columns[1] | not needed
        let channelTitle = columns[2]
        return SendableSubscription(title: channelTitle, youtubeChannelId: channelId)
    }
}

struct MyButtonStyle: ButtonStyle {
    @AppStorage(Const.themeColor) var theme = ThemeColor()

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .foregroundColor(theme.contrastColor)
            .background(theme.color)
            .cornerRadius(5)
    }
}

#Preview {
    ImportSubscriptionsView(
        sendableSubs: [
            SendableSubscription(title: "habie147", youtubeChannelId: "UC-FHoOa_jNSZy3IFctMEq2w"),
            SendableSubscription(title: "Broken Back", youtubeChannelId: "UC0q0O1XksvAATq_uH7IiEOA"),
            SendableSubscription(title: "CGPGrey2", youtubeChannelId: "UC127Qy2ulgASLYvW4AuHJZQ"),
            SendableSubscription(title: "CGP Grey", youtubeChannelId: "UC2C_jShtL725hvbm1arSV9w"),
            SendableSubscription(title: "Auto Focus", youtubeChannelId: "UC2J-0g_nxlwcD9JBK1eTleQ"),
            SendableSubscription(title: "LastWeekTonight", youtubeChannelId: "UC3XTzVzaHQEd30rQbuvCtTQ"),
            SendableSubscription(title: "habie147", youtubeChannelId: "UC-FHoOa_jNSZy3IFctMEq2w"),
            SendableSubscription(title: "Broken Back", youtubeChannelId: "UC0q0O1XksvAATq_uH7IiEOA"),
            SendableSubscription(title: "CGPGrey2", youtubeChannelId: "UC127Qy2ulgASLYvW4AuHJZQ"),
            SendableSubscription(title: "CGP Grey", youtubeChannelId: "UC2C_jShtL725hvbm1arSV9w"),
            SendableSubscription(title: "Auto Focus", youtubeChannelId: "UC2J-0g_nxlwcD9JBK1eTleQ"),
            SendableSubscription(title: "LastWeekTonight", youtubeChannelId: "UC3XTzVzaHQEd30rQbuvCtTQ"),
            SendableSubscription(title: "habie147", youtubeChannelId: "UC-FHoOa_jNSZy3IFctMEq2w"),
            SendableSubscription(title: "Broken Back", youtubeChannelId: "UC0q0O1XksvAATq_uH7IiEOA"),
            SendableSubscription(title: "CGPGrey2", youtubeChannelId: "UC127Qy2ulgASLYvW4AuHJZQ"),
            SendableSubscription(title: "CGP Grey", youtubeChannelId: "UC2C_jShtL725hvbm1arSV9w"),
            SendableSubscription(title: "Auto Focus", youtubeChannelId: "UC2J-0g_nxlwcD9JBK1eTleQ"),
            SendableSubscription(title: "LastWeekTonight", youtubeChannelId: "UC3XTzVzaHQEd30rQbuvCtTQ")
        ]
    )
    .modelContainer(DataProvider.previewContainer)
    .environment(RefreshManager())
}
