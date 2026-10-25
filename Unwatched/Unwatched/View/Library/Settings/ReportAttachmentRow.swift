//
//  ReportAttachmentRow.swift
//  Unwatched
//

import PhotosUI
import SwiftUI
import UnwatchedShared

struct ReportAttachmentRow: View {
    @Binding var attachment: IssueReportAttachment?
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?

    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        Group {
            if isLoading {
                HStack {
                    Text("preparingAttachment")
                    Spacer()
                    ProgressView()
                }
            } else if let attachment {
                HStack(spacing: 12) {
                    preview(attachment)
                        .frame(width: 44, height: 44)
                        .clipShape(.rect(cornerRadius: 6))
                    Text(attachment.data.count.formatted(.byteCount(style: .file)))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("remove", role: .destructive) {
                        pickerItem = nil
                    }
                }
            } else {
                PhotosPicker(selection: $pickerItem, matching: .any(of: [.images, .videos])) {
                    Label("addScreenshotOrRecording", systemImage: "photo.badge.plus")
                }
                .settingsListRow()
            }
        }
        .onChange(of: pickerItem) {
            load()
        }
    }

    @ViewBuilder
    private func preview(_ attachment: IssueReportAttachment) -> some View {
        if let thumbnail = attachment.thumbnail {
            Image(decorative: thumbnail, scale: 1)
                .resizable()
                .scaledToFill()
        } else {
            Image(systemName: "video.fill")
                .foregroundStyle(.secondary)
        }
    }

    private func load() {
        attachment = nil
        isLoading = pickerItem != nil
        guard let pickerItem else { return }
        Task {
            let result = await Result { try await IssueReportAttachment.load(pickerItem) }
            guard pickerItem == self.pickerItem else { return }
            isLoading = false
            switch result {
            case .success(let loaded):
                attachment = loaded
            case .failure(let error):
                Log.error("loading report attachment: \(error)")
                self.pickerItem = nil
                errorMessage = error.localizedDescription
            }
        }
    }
}
