//
//  ReportAttachmentRow.swift
//  Unwatched
//

import PhotosUI
import SwiftUI
import UnwatchedShared

/// The picked attachments as rows, the ones still loading below them, and the add button last.
struct ReportAttachmentRow: View {
    static let maxCount = 5

    @Binding var attachments: [IssueReportAttachment]
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var pendingCount = 0

    var body: some View {
        ForEach(attachments) { attachment in
            HStack(spacing: 12) {
                preview(attachment)
                    .frame(width: 44, height: 44)
                    .clipShape(.rect(cornerRadius: 6))
                Text(attachment.data.count.formatted(.byteCount(style: .file)))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("remove", role: .destructive) {
                    withAnimation {
                        attachments.removeAll { $0.id == attachment.id }
                    }
                }
                .buttonStyle(.borderless)
            }
        }

        ForEach(0..<pendingCount, id: \.self) { _ in
            HStack {
                Text("preparingAttachment")
                Spacer()
                ProgressView()
            }
        }

        if remainingCount > 0 {
            PhotosPicker(
                selection: $pickerItems,
                maxSelectionCount: remainingCount,
                selectionBehavior: .ordered,
                matching: .any(of: [.images, .videos])
            ) {
                Label("addScreenshotOrRecording", systemImage: "photo.badge.plus")
            }
            .settingsListRow()
            .onChange(of: pickerItems) {
                load()
            }
        }
    }

    private var remainingCount: Int {
        Self.maxCount - attachments.count - pendingCount
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

    /// Hands the picked items off and clears the selection, so the picker opens empty for the next batch.
    private func load() {
        let items = pickerItems
        guard !items.isEmpty else { return }
        withAnimation {
            pickerItems = []
            pendingCount += items.count
            isLoading = true
        }
        Task {
            for item in items {
                let result = await Result { try await IssueReportAttachment.load(item) }
                // one animated update for all of it, or the List drops the insert animation
                withAnimation {
                    pendingCount -= 1
                    isLoading = pendingCount > 0
                    if case .success(let loaded) = result {
                        attachments.append(loaded)
                    }
                }
                if case .failure(let error) = result {
                    Log.error("loading report attachment: \(error)")
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
