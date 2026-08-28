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

    @State private var showFileImporter = false
    @State var sendableSubs = [SendableSubscription]()
    @State var subStates = [SubscriptionState]()

    @State private var selection = Set<SendableSubscription>()
    #if os(iOS) || os(visionOS)
    @State private var editMode = EditMode.active
    #else
    @State private var editMode = NSTableView.SelectionHighlightStyle.regular
    #endif
    @State private var isLoading = false
    @State private var fileLoaded = false
    @State private var searchString = ""
    @State private var loadSubStatesTask: Task<[SubscriptionState], Error>?

    var importButtonPadding = false
    var opmlUrl: URL?
    var onSuccess: (() -> Void)?

    var filteredSubs: [SendableSubscription] {
        guard !searchString.isEmpty else { return sendableSubs }
        return sendableSubs.filter { $0.title.localizedStandardContains(searchString) }
    }

    var importButtonLabel: String {
        String(AttributedString(
            localized: "importSubscriptions ^[\(selection.count) subscription](inflect: true)"
        ).characters)
    }

    var body: some View {
        VStack {
            if sendableSubs.isEmpty {
                if opmlUrl != nil && !fileLoaded {
                    ProgressView()
                } else {
                    ExportImportTutorial(showFileImporter: $showFileImporter)
                }
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
                        if !filteredSubs.isEmpty {
                            ForEach(filteredSubs, id: \.self) { sub in
                                Text(sub.title)
                                    .listRowBackground(MyBackgroundColor(macOS: false))
                            }
                            Spacer()
                                .frame(height: 50)
                                .listRowSeparator(.hidden)
                                .listRowBackground(MyBackgroundColor(macOS: false))
                        }
                    }
                    .scrollContentBackground(.hidden)
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
                            Text(importButtonLabel)
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
            MyBackgroundColor(macOS: false)
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.plainText, .opml, .xml],
            onCompletion: handleFileImport
        )
        .task {
            if let opmlUrl {
                readFile(opmlUrl)
            }
        }
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
        Task.detached(priority: .userInitiated) {
            let parsed = Self.parseFile(file)
            await MainActor.run {
                sendableSubs = parsed
                selection = Set(parsed)
                fileLoaded = true
            }
        }
    }

    nonisolated static func parseFile(_ file: URL) -> [SendableSubscription] {
        do {
            let isSecureAccess = file.startAccessingSecurityScopedResource()
            defer {
                if isSecureAccess {
                    file.stopAccessingSecurityScopedResource()
                }
            }
            let content = try String(contentsOf: file)
            let isXML = file.pathExtension.lowercased() == "opml"
                || content.trimmingCharacters(in: .whitespaces).hasPrefix("<")
            if isXML {
                return parseOPML(content)
            }
            return parseRows(content.components(separatedBy: "\n"))
        } catch {
            Log.error("Failed to read file: \(error)")
            return []
        }
    }

    nonisolated static func parseOPML(_ content: String) -> [SendableSubscription] {
        guard let data = content.data(using: .utf8) else { return [] }
        let parser = OPMLParser(data: data)
        return parser.parse().sorted(by: { $0.title < $1.title })
    }

    nonisolated static func parseRows(_ rows: [String]) -> [SendableSubscription] {
        var result = [SendableSubscription]()
        for row in rows.dropFirst() where !row.isEmpty {
            if let sub = parseRow(row) {
                result.append(sub)
            }
        }
        return result.sorted(by: { $0.title < $1.title })
    }

    nonisolated static func parseRow(_ row: String) -> SendableSubscription? {
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
