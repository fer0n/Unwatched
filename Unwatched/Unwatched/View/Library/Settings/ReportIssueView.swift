//
//  ReportIssueView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct ReportIssueView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var message = ""
    @State private var contact = ""
    @State private var includeLogs = true
    @State private var attachments: [IssueReportAttachment] = []
    @State private var isLoadingAttachment = false
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var showSent = false

    @FocusState private var messageFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                MyBackgroundColor()

                MyForm {
                    MySection {
                        TextField("reportIssueMessage", text: $message, axis: .vertical)
                            .lineLimit(5...12)
                            .focused($messageFocused)
                    }

                    MySection(footer: "reportIssueContactFooter") {
                        TextField("reportIssueContact", text: $contact)
                            .textContentType(.emailAddress)
                            .autocorrectionDisabled()
                            #if os(iOS) || os(visionOS)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                        #endif
                    }

                    MySection(footer: "includeLogsFooter") {
                        Toggle("includeLogs", isOn: $includeLogs)
                    }

                    MySection {
                        ReportAttachmentRow(
                            attachments: $attachments,
                            isLoading: $isLoadingAttachment,
                            errorMessage: $errorMessage
                        )
                    }
                }
            }
            .myTint()
            .myNavigationTitle("reportIssue")
            .toolbar {
                toolbarContent
            }
            .disabled(isSending)
        }
        #if os(macOS)
        .frame(width: 500, height: 600)
        #endif
        .interactiveDismissDisabled(isSending || !message.isEmpty)
        .alert("reportFailed", isPresented: showError) {
            Button("ok") { }
        } message: {
            Text(verbatim: errorMessage ?? "")
        }
        .alert("reportSent", isPresented: $showSent) {
            Button("ok") {
                dismiss()
            }
        } message: {
            Text("reportSentMessage")
        }
        .task {
            messageFocused = true
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            DismissSheetButton()
        }
        ToolbarItem(placement: .confirmationAction) {
            if isSending {
                ProgressView()
            } else {
                Button("sendReport", systemImage: "paperplane.fill", action: send)
                    .fontWeight(.bold)
                    .disabled(trimmed(message).isEmpty || isLoadingAttachment)
            }
        }
    }

    private var showError: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func send() {
        isSending = true
        Task {
            defer { isSending = false }
            do {
                try await IssueReportService.send(
                    message: trimmed(message),
                    contact: trimmed(contact),
                    includeLogs: includeLogs,
                    attachments: attachments
                )
                showSent = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview {
    ReportIssueView()
}
