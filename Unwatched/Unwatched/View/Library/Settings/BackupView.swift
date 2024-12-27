//
//  BackupView.swift
//  Unwatched
//

import SwiftUI
import OSLog
import UnwatchedShared

struct BackupView: View {
    @Environment(PlayerManager.self) var player
    @Environment(\.modelContext) var modelContext
    @Environment(Alerter.self) private var alerter

    @State var showFileImporter = false
    @State var showDeleteConfirmation = false
    @State var fileNames = [URL]()
    @State var fileToBeRestored: IdentifiableURL?

    @State var isDeletingEverythingTask: Task<(), Never>?

    var body: some View {
        let backupType = Const.backupType ?? .json

        ZStack {
            Color.backgroundColor.ignoresSafeArea(.all)

            MyForm {
                BackupSettings()

                MySection {
                    AsyncButton {
                        await saveToIcloud(deviceName)
                    } label: {
                        Text("backupNow")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        showFileImporter = true
                    } label: {
                        Text("importBackup")
                    }
                }

                if !fileNames.isEmpty {
                    MySection("latestUnwatchedBackups") {
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
                                        if info.isManual {
                                            Text(verbatim: " \(Const.dotString) ")
                                            Text("manualBackup")
                                        }
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete(perform: deleteFile)
                    }
                }

                AutoDeleteBackupView()

                MySection {
                    DeleteImageCacheButton()

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
        }
        .actionSheet(item: $fileToBeRestored) { restoreFile in
            ActionSheet(title: Text("restoreThisBackup?"),
                        message: Text("restoreThisBackupMessage"),
                        buttons: [
                            .destructive(Text("restoreBackup")) { restoreBackup(restoreFile.url) },
                            .cancel()
                        ])
        }
        .myNavigationTitle("userData")
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
        .task(id: isDeletingEverythingTask) {
            guard isDeletingEverythingTask != nil else { return }
            await isDeletingEverythingTask?.value
            isDeletingEverythingTask = nil
        }
        .onAppear {
            getAllIcloudFiles()
        }
    }

    var deviceName: String {
        if UIDevice.isMac {
            "Mac"
        } else {
            UIDevice.current.name
        }
    }

    func deleteFile(at offsets: IndexSet) {
        guard let index = offsets.first else {
            Logger.log.error("deleteFile: offsets is empty")
            return
        }

        let fileURL = fileNames[index]
        do {
            try FileManager.default.removeItem(at: fileURL)
            fileNames.remove(atOffsets: offsets)
            getAllIcloudFiles()
        } catch {
            Logger.log.error("deleteFile: \(error)")
        }
    }

    func getFileInfo(_ file: URL) -> FileInfo {
        let fileName = file.lastPathComponent
        let deviceName = fileName.contains("_")
            ? fileName.components(separatedBy: "_").first
            : nil
        var fileSizeString: String?
        var dateString: String?
        let isManual = fileName.contains("_m")

        if let fileAttributes = try? FileManager.default.attributesOfItem(atPath: file.path) {
            if let fileSizeInBytes = fileAttributes[.size] as? Int64 {
                fileSizeString = ByteCountFormatter.string(fromByteCount: fileSizeInBytes, countStyle: .file)
            }
            if let date = fileAttributes[.creationDate] as? Date {
                dateString = date.formatted()
            }
        }
        return FileInfo(deviceName: deviceName,
                        dateString: dateString,
                        fileSizeString: fileSizeString,
                        isManual: isManual)
    }

    func saveToIcloud(_ deviceName: String) async {
        do {
            let container = modelContext.container
            let task = UserDataService.saveToIcloud(deviceName, container, manual: true)
            try await task.value
            self.getAllIcloudFiles()
        } catch {
            alerter.showError(error)
        }
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
            player.clearVideo(modelContext)
        }
        let task = Task {
            await VideoService.deleteEverything(container)
        }
        isDeletingEverythingTask = task
        UserDefaults.standard.set(0, forKey: Const.newQueueItemsCount)
        UserDefaults.standard.set(0, forKey: Const.newInboxItemsCount)
        return task
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
