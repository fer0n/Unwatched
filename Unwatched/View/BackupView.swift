//
//  BackupView.swift
//  Unwatched
//

import SwiftUI

struct BackupView: View {
    @Environment(PlayerManager.self) var player
    @Environment(\.modelContext) var modelContext

    @AppStorage(Const.automaticBackups) var automaticBackups = true

    @State var isExporting = false
    @State var isExportingAll = false
    @State var showFileImporter = false
    @State var isDeleting = false
    @State var isDeletingEverything = false
    @State var showDeleteConfirmation = false
    @State var fileNames = [URL]()
    @State var fileToBeRestored: IdentifiableURL?

    var body: some View {
        let backupType = Const.backupType ?? .json

        List {
            let feedUrls = AsyncSharableUrls(getUrls: exportAllSubscriptions, isLoading: $isExportingAll)
            ShareLink(item: feedUrls, preview: SharePreview("exportSubscriptions")) {
                if isExportingAll {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("exportSubscriptions")
                    }
                }
            }

            Section(header: Text("automaticBackups"), footer: Text("automaticBackupsHelper")) {
                Toggle(isOn: $automaticBackups) {
                    Text("backupToIcloud")
                }
                .tint(.teal)
            }

            Button {
                saveToIcloud()
            } label: {
                Text("backupNow")
            }

            Button {
                showFileImporter = true
            } label: {
                Text("importBackup")
            }

            if !fileNames.isEmpty {
                Section("latestUnwatchedBackups") {
                    ForEach(fileNames, id: \.self) { file in
                        if let date = try? file.resourceValues(forKeys: [.creationDateKey]).creationDate {
                            Button {
                                fileToBeRestored = IdentifiableURL(url: file)
                            } label: {
                                Text(date.formatted())
                            }
                        }
                    }
                }
            }

            Section {
                Button(role: .destructive, action: {
                    deleteImageCache()
                }, label: {
                    if isDeleting {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        Text("deleteImageCache")
                    }
                })

                Button(role: .destructive, action: {
                    showDeleteConfirmation = true
                }, label: {
                    if isDeletingEverything {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        Text("deleteEverything")
                    }
                })
                .actionSheet(isPresented: $showDeleteConfirmation) {
                    ActionSheet(title: Text("confirmDeleteEverything"),
                                message: Text("confirmDeleteEverythingMessage"),
                                buttons: [
                                    .destructive(Text("deleteEverything")) { _ = deleteEverything() },
                                    .cancel()
                                ])
                }
            }
        }
        .actionSheet(item: $fileToBeRestored) { restoreFile in
            ActionSheet(title: Text("restoreThisBackup?"),
                        message: Text("restoreThisBackupMessage"),
                        buttons: [
                            .destructive(Text("restoreBackup")) { restoreBackup(restoreFile.url) },
                            .cancel()
                        ])
        }
        .navigationTitle("backup")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $showFileImporter,
                      allowedContentTypes: [backupType]) { result in
            switch result {
            case .success(let file):
                importFile(file)
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
        .onAppear {
            getAllIcloudFiles()
        }
    }

    func saveToIcloud() {
        isExporting = true
        let container = modelContext.container
        let task = UserDataService.saveToIcloud(container)
        Task {
            await task.value
            await MainActor.run {
                self.getAllIcloudFiles()
                isExporting = false
            }
        }
    }

    func restoreBackup(_ file: URL) {
        let task = deleteEverything()
        importFile(file, after: task)
    }

    func getAllIcloudFiles() {
        let fileManager = FileManager.default
        guard let backupsUrl = UserDataService.getBackupsDirectory() else {
            print("no documents url")
            return
        }
        withAnimation {
            do {
                let fileUrls = try fileManager
                    .contentsOfDirectory(at: backupsUrl, includingPropertiesForKeys: [.creationDateKey])
                let sortedFileUrls = fileUrls.sorted {
                    let date0 = try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate
                    let date1 = try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate
                    return date0 ?? .distantPast > date1 ?? .distantPast
                }
                fileNames = Array(sortedFileUrls.prefix(5))
            } catch {
                print("Error while enumerating files \(backupsUrl.path): \(error.localizedDescription)")
            }
        }
    }

    func deleteEverything() -> Task<(), Never>? {
        if isDeletingEverything { return nil }
        let container = modelContext.container
        isDeletingEverything = true
        withAnimation {
            player.clearVideo()
        }
        let task = Task {
            await VideoService.deleteEverything(container)
            await MainActor.run {
                self.isDeletingEverything = false
            }
        }
        return task
    }

    func deleteImageCache() {
        if isDeleting { return }
        let container = modelContext.container
        isDeleting = true
        Task {
            let task = ImageService.deleteAllImages(container)
            try? await task.value
            await MainActor.run {
                self.isDeleting = false
            }
        }
    }

    func exportAllSubscriptions() async -> [(title: String, link: URL?)] {
        let container = modelContext.container
        let result = try? await SubscriptionService.getAllFeedUrls(container)
        return result ?? []
    }

    func importFile(_ filePath: URL, after: Task<(), Never>? = nil) {
        print("importFile:", filePath)
        let container = modelContext.container
        let isSecureAccess = filePath.startAccessingSecurityScopedResource()

        Task {
            await after?.value
            if let data = try? Data(contentsOf: filePath) {
                UserDataService.importBackup(data, container: container)
            }
            if isSecureAccess {
                filePath.stopAccessingSecurityScopedResource()
            }
        }
    }
}

struct AsyncSharableUrls: Transferable {
    let getUrls: () async -> [(title: String, link: URL?)]
    @Binding var isLoading: Bool

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .plainText) { item in
            item.isLoading = true
            let urls = await item.getUrls()
            let textUrls = urls
                .map { "\($0.title)\n\($0.link?.absoluteString ?? "...")\n" }
                .joined(separator: "\n")
            print("textUrls", textUrls)
            let data = textUrls.data(using: .utf8)
            if let data = data {
                item.isLoading = false
                return data
            } else {
                fatalError()
            }
            item.isLoading = false
        }
    }
}

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

#Preview {
    BackupView()
}
