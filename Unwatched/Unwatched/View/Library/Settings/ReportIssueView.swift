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
    @State private var isSent = false
    @State private var logs: Task<Data, Never>?

    @FocusState private var messageFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                MyBackgroundColor()

                if isSent {
                    ReportSentView()
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                } else {
                    form
                }
            }
            .myTint()
            .myNavigationTitle("reportIssue")
            .toolbar {
                toolbarContent
            }
            .disabled(isSending || isSent)
        }
        #if os(macOS)
        .frame(width: 500, height: 600)
        #endif
        .interactiveDismissDisabled(isSending || (!message.isEmpty && !isSent))
        .alert("reportFailed", isPresented: showError) {
            Button("ok") { }
        } message: {
            Text(verbatim: errorMessage ?? "")
        }
        .task {
            if logs == nil {
                logs = Task { await IssueReportService.prepareLogs() }
            }
            messageFocused = true
        }
        .onDisappear {
            logs?.cancel()
        }
    }

    private var form: some View {
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
            do {
                let logData = includeLogs ? await logs?.value : nil
                try await IssueReportService.send(
                    message: trimmed(message),
                    contact: trimmed(contact),
                    logs: logData,
                    attachments: attachments
                )
                messageFocused = false
                withAnimation(.spring(duration: 0.4, bounce: 0.3)) {
                    isSending = false
                    isSent = true
                }
            } catch {
                isSending = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct ReportSentView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var bounce = false

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .symbolEffect(.bounce, value: bounce)
            Text("reportSent")
                .font(.title3)
                .fontWeight(.semibold)
            Text("reportSentMessage")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .task {
            bounce = true
            do {
                try await Task.sleep(for: .seconds(1.6))
                dismiss()
            } catch {}
        }
    }
}

#Preview {
    ReportIssueView()
}
