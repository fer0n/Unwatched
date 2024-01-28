//
//  BackupView.swift
//  Unwatched
//

import SwiftUI

struct BackupView: View {
    @Environment(PlayerManager.self) var player
    @Environment(\.modelContext) var modelContext

    @State var isExporting = false
    @State var isExportingAll = false
    @State var showFileImporter = false
    @State var isDeleting = false
    @State var isDeletingEverything = false
    @State var showDeleteConfirmation = false

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

            Section {
                let item = AsyncSharableFile(getFile: exportFile, isLoading: $isExporting)
                ShareLink(item: item, preview: SharePreview("exportSubscriptions")) {
                    Text("backupNow")
                }

                Button {
                    showFileImporter = true
                } label: {
                    Text("importBackup")
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
                                    .destructive(Text("deleteEverything")) { deleteEverything() },
                                    .cancel()
                                ])
                }
            }
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

    }

    func deleteEverything() {
        if isDeletingEverything { return }
        let container = modelContext.container
        isDeletingEverything = true
        withAnimation {
            player.clearVideo()
        }
        Task {
            await VideoService.deleteEverything(container)
            await MainActor.run {
                self.isDeletingEverything = false
            }
        }
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

    func exportAllSubscriptions() async -> [(title: String, link: URL)] {
        let container = modelContext.container
        let result = try? await SubscriptionService.getAllFeedUrls(container)
        return result ?? []
    }

    func exportFile() -> Data? {
        print("backupNow")
        let container = modelContext.container
        do {
            return try UserDataService.exportUserData(container: container)
        } catch {
            print("couldn't export: \(error)")
        }
        return nil
    }

    func importFile(_ filePath: URL) {
        let container = modelContext.container
        if filePath.startAccessingSecurityScopedResource() {

            guard let data = try? Data(contentsOf: filePath) else {
                print("no data")
                return
            }
            UserDataService.importBackup(data, container: container)
        }
        filePath.stopAccessingSecurityScopedResource()
    }
}

struct AsyncSharableFile: Transferable {
    let getFile: () -> Data?
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
        .suggestedFileName { _ in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd-hh-mm"
            let dateString = formatter.string(from: Date())
            return "\(dateString).unwatchedbackup"
        }
    }
}

struct AsyncSharableUrls: Transferable {
    let getUrls: () async -> [(title: String, link: URL)]
    @Binding var isLoading: Bool

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .plainText) { item in
            item.isLoading = true
            let urls = await item.getUrls()
            let textUrls = urls
                .map { "\($0.title)\n\($0.link.absoluteString)\n" }
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

#Preview {
    BackupView()
}
