//
//  BackupView.swift
//  Unwatched
//

import SwiftUI
import OSLog

struct BackupView: View {
    @Environment(PlayerManager.self) var player
    @Environment(\.modelContext) var modelContext
    @Environment(Alerter.self) private var alerter

    @AppStorage(Const.automaticBackups) var automaticBackups = true
    @AppStorage(Const.minimalBackups) var minimalBackups = true
    @AppStorage(Const.enableIcloudSync) var enableIcloudSync = false

    @State var showFileImporter = false
    @State var showDeleteConfirmation = false
    @State var fileNames = [URL]()
    @State var fileToBeRestored: IdentifiableURL?

    @State var isDeletingTask: Task<(), Never>?
    @State var isDeletingEverythingTask: Task<(), Never>?
    @State var saveToIcloudTask: Task<(), any Error>?

    var body: some View {
        let backupType = Const.backupType ?? .json

        List {

            Section(header: Text("icloudSync"), footer: Text("icloudSyncHelper")) {
                Toggle(isOn: $enableIcloudSync) {
                    Text("syncToIcloud")
                }
                .tint(.teal)
            }

            Section(header: Text("automaticBackups"), footer: Text("automaticBackupsHelper")) {
                Toggle(isOn: $automaticBackups) {
                    Text("backupToIcloud")
                }
                .tint(.teal)
            }

            Section(footer: Text("minimalBackupsHelper")) {
                Toggle(isOn: $minimalBackups) {
                    Text("minimalBackups")
                }
                .tint(.teal)
            }

            AsyncButton {
                await saveToIcloud(UIDevice.current.name)
            } label: {
                Text("backupNow")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                showFileImporter = true
            } label: {
                Text("importBackup")
            }

            if !fileNames.isEmpty {
                Section("latestUnwatchedBackups") {
                    ForEach(fileNames, id: \.self) { file in
                        let info = getFileInfo(file)
                        Button {
                            fileToBeRestored = IdentifiableURL(url: file)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(info.dateString ?? "unknown date")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                HStack(spacing: 0) {
                                    if let device = info.deviceName {
                                        Text(device)
                                    }
                                    if info.deviceName != nil && info.fileSizeString != nil {
                                        Text(verbatim: " \(Const.dotString) ")
                                    }
                                    if let size = info.fileSizeString {
                                        Text(verbatim: size)
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section {
                Button(role: .destructive, action: {
                    deleteImageCache()
                }, label: {
                    if isDeletingTask != nil {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        Text("deleteImageCache")
                    }
                })

                Button(role: .destructive, action: {
                    showDeleteConfirmation = true
                }, label: {
                    if isDeletingEverythingTask != nil {
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
        .navigationTitle("userData")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $showFileImporter,
                      allowedContentTypes: [backupType]) { result in
            switch result {
            case .success(let file):
                fileToBeRestored = IdentifiableURL(url: file)
            case .failure(let error):
                Logger.log.error("\(error.localizedDescription)")
            }
        }
        .task(id: isDeletingTask) {
            guard isDeletingTask != nil else { return }
            await isDeletingTask?.value
            isDeletingTask = nil
        }
        .task(id: isDeletingEverythingTask) {
            guard isDeletingEverythingTask != nil else { return }
            await isDeletingEverythingTask?.value
            isDeletingEverythingTask = nil
        }
        .task(id: saveToIcloudTask) {
            do {
                try await saveToIcloudTask?.value
                self.getAllIcloudFiles()
            } catch {
                alerter.showError(error)
            }
        }
        .onAppear {
            getAllIcloudFiles()
        }
    }

    func getFileInfo(_ file: URL) -> FileInfo {
        let fileName = file.lastPathComponent
        let deviceName = fileName.contains("_")
            ? fileName.components(separatedBy: "_").first
            : nil
        var fileSizeString: String?
        var dateString: String?

        if let fileAttributes = try? FileManager.default.attributesOfItem(atPath: file.path) {
            if let fileSizeInBytes = fileAttributes[.size] as? Int64 {
                fileSizeString = ByteCountFormatter.string(fromByteCount: fileSizeInBytes, countStyle: .file)
            }
            if let date = fileAttributes[.creationDate] as? Date {
                dateString = date.formatted()
            }
        }
        return FileInfo(deviceName: deviceName, dateString: dateString, fileSizeString: fileSizeString)
    }

    func saveToIcloud(_ deviceName: String) async {
        let container = modelContext.container
        saveToIcloudTask = UserDataService.saveToIcloud(deviceName, container)
    }

    func restoreBackup(_ file: URL) {
        let task = deleteEverything()
        importFile(file, after: task)
    }

    func getAllIcloudFiles() {
        let fileManager = FileManager.default
        guard let backupsUrl = UserDataService.getBackupsDirectory() else {
            Logger.log.warning("no documents url")
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
                Logger.log.error("Error while enumerating files \(backupsUrl.path): \(error.localizedDescription)")
            }
        }
    }

    func deleteEverything() -> Task<(), Never>? {
        if isDeletingEverythingTask != nil { return nil }
        let container = modelContext.container
        withAnimation {
            player.clearVideo()
        }
        let task = Task {
            await VideoService.deleteEverything(container)
        }
        isDeletingEverythingTask = task
        return task
    }

    func deleteImageCache() {
        if isDeletingTask != nil { return }
        let container = modelContext.container
        isDeletingTask = Task {
            let task = ImageService.deleteAllImages(container)
            try? await task.value
        }
    }

    func importFile(_ filePath: URL, after: Task<(), Never>? = nil) {
        Logger.log.info("importFile: \(filePath)")
        let container = modelContext.container
        let isSecureAccess = filePath.startAccessingSecurityScopedResource()

        Task {
            await after?.value
            Logger.log.info("after task done")
            do {
                let data = try Data(contentsOf: filePath)
                Logger.log.info("data is there")
                UserDataService.importBackup(data, container: container)
            } catch {
                Logger.log.error("error when importing: \(error)")
            }
            if isSecureAccess {
                filePath.stopAccessingSecurityScopedResource()
            }
        }
    }
}

#Preview {
    BackupView()
        .modelContainer(DataController.previewContainer)
        .environment(NavigationManager())
        .environment(PlayerManager())
        .environment(RefreshManager())
        .environment(ImageCacheManager())
        .environment(Alerter())
}

struct FileInfo {
    let deviceName: String?
    let dateString: String?
    let fileSizeString: String?
}
