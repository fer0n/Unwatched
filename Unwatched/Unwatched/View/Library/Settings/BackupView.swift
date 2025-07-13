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

    @State var showFileImporter = false
    @State var showDeleteConfirmation = false
    @State var fileNames = [URL]()
    @State var fileToBeRestored: IdentifiableURL?

    @State var isDeletingEverythingTask: Task<(), Never>?
    @State var hasicloudDirectory = true
    @State var isExporting = false

    var body: some View {
        let backupType = Const.backupType ?? .json

        ZStack {
            Color.backgroundColor.ignoresSafeArea(.all)

            MyForm {
                BackupSettings()

                MySection {
                    Button {
                        showFileImporter = true
                    } label: {
                        Text("importBackup")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    let item = AsyncSharableFile(
                        getFile: exportFile,
                        filename: UserDataService.getBackupFileName(
                            manual: true
                        ),
                        isLoading: $isExporting
                    )
                    ShareLink(item: item, preview: SharePreview("backupNow")) {
                        if isExporting {
                            ProgressView()
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            Text("exportBackup")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }

                MySection(footer: !hasicloudDirectory ? "noIcloudBackupWarning" : "") {
                    AsyncButton {
                        await saveBackupFile()
                    } label: {
                        Text("backupNow")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .disabled(!hasicloudDirectory)
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
                    DeleteTranscriptCacheButton()

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
                    .confirmationDialog("confirmDeleteEverything",
                                        isPresented: $showDeleteConfirmation,
                                        titleVisibility: .visible,
                                        actions: {
                                            Button("deleteEverything", role: .destructive) {
                                                _ = deleteEverything()
                                            }
                                            Button("cancel", role: .cancel) { }
                                        },
                                        message: {
                                            Text("confirmDeleteEverythingMessage")
                                        })
                }
            }
        }
        .confirmationDialog("restoreThisBackup?",
                            isPresented: .init(
                                get: { fileToBeRestored != nil },
                                set: { if !$0 { fileToBeRestored = nil } }
                            ),
                            titleVisibility: .visible
        ) {
            if let file = fileToBeRestored {
                Button("restoreSettingsFromBackup") {
                    restoreSettingsFromBackup(file.url)
                }
                Button("restoreBackup", role: .destructive) {
                    restoreBackup(file.url)
                }
                Button("cancel", role: .cancel) { }
            }
        } message: {
            Text("restoreThisBackupMessage")
        }
        .myNavigationTitle("userData")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .fileImporter(isPresented: $showFileImporter,
                      allowedContentTypes: [backupType]) { result in
            switch result {
            case .success(let file):
                fileToBeRestored = IdentifiableURL(url: file)
            case .failure(let error):
                Log.error("\(error.localizedDescription)")
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

    func deleteFile(at offsets: IndexSet) {
        guard let index = offsets.first else {
            Log.error("deleteFile: offsets is empty")
            return
        }

        let fileURL = fileNames[index]
        do {
            try FileManager.default.removeItem(at: fileURL)
            fileNames.remove(atOffsets: offsets)
            getAllIcloudFiles()
        } catch {
            Log.error("deleteFile: \(error)")
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

    func exportFile() -> Data? {
        do {
            let data = try UserDataService.exportUserData()
            return data
        } catch {
            Log.error("Export failed: \(error)")
            return nil
        }
    }

    func saveBackupFile() async {
        do {
            let task = UserDataService.saveToIcloud(manual: true)
            try await task.value
            self.getAllIcloudFiles()
        } catch {
            Log.error("\(error)")
        }
    }

    func restoreBackup(_ file: URL) {
        let task = deleteEverything()
        doWithFileData(file, after: task) { data in
            UserDataService.importBackup(data)
        }
    }

    func restoreSettingsFromBackup(_ file: URL) {
        doWithFileData(file) { data in
            UserDataService.importBackup(data, settingsOnly: true)
        }
    }

    func getAllIcloudFiles() {
        let fileManager = FileManager.default
        guard let backupsUrl = UserDataService.getBackupsDirectory() else {
            Log.warning("no documents url")
            hasicloudDirectory = false
            return
        }
        hasicloudDirectory = true
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
                Log.error("Error while enumerating files \(backupsUrl.path): \(error.localizedDescription)")
            }
        }
    }

    func deleteEverything() -> Task<(), Never>? {
        if isDeletingEverythingTask != nil { return nil }
        withAnimation {
            player.clearVideo(modelContext)
            player.video = nil
        }
        let task = Task {
            await VideoService.deleteEverything()
        }
        isDeletingEverythingTask = task
        return task
    }

    func doWithFileData(_ filePath: URL,
                        after: Task<(), Never>? = nil,
                        action: @escaping (Data) -> Void) {
        Log.info("importFile: \(filePath)")
        let isSecureAccess = filePath.startAccessingSecurityScopedResource()

        Task {
            await after?.value
            Log.info("after task done")
            do {
                let data = try Data(contentsOf: filePath)
                Log.info("data is there")
                action(data)
            } catch {
                Log.error("error when importing: \(error)")
            }
            if isSecureAccess {
                filePath.stopAccessingSecurityScopedResource()
            }
        }
    }
}

struct AsyncSharableFile: Transferable {
    let getFile: () -> Data?
    var filename: String
    @Binding var isLoading: Bool

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .data) { item in
            item.isLoading = true
            if let data = item.getFile() {
                item.isLoading = false
                return data
            } else {
                item.isLoading = false
                fatalError()
            }
        }
        .suggestedFileName { $0.filename }
    }
}

#Preview {
    BackupView()
        .modelContainer(DataProvider.previewContainer)
        .environment(NavigationManager())
        .environment(PlayerManager())
        .environment(RefreshManager())
        .environment(ImageCacheManager())
        .environment(Alerter())
}
