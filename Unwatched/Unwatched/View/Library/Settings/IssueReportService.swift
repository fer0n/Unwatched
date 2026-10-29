//
//  IssueReportService.swift
//  Unwatched
//

import Foundation
import OSLog
import UnwatchedShared

enum IssueReportService {
    static func send(
        message: String,
        contact: String,
        includeLogs: Bool,
        attachments: [IssueReportAttachment]
    ) async throws {
        guard let url = URL(string: "\(Credentials.analyticsEndpoint)/report") else {
            throw IssueReportError.server(0)
        }

        var form = MultipartForm()
        form.addField("message", message)
        form.addField("contact", contact)
        form.addField("appVersion", appVersion)
        form.addField("build", build)
        form.addField("channel", BuildInfo.channel)
        form.addField("os", system)
        form.addField("device", device)
        if includeLogs, let logs = await collectLogs() {
            form.addFile("log", fileName: "Unwatched.log", mimeType: "text/plain", data: logs)
        }
        for attachment in attachments {
            form.addFile(
                "attachment",
                fileName: attachment.fileName,
                mimeType: attachment.mimeType,
                data: attachment.data
            )
        }

        var request = URLRequest(url: url, timeoutInterval: 120)
        request.httpMethod = "POST"
        request.setValue("Bearer \(Credentials.analyticsSecret)", forHTTPHeaderField: "Authorization")
        request.setValue(form.contentType, forHTTPHeaderField: "Content-Type")

        let (_, response) = try await URLSession.shared.upload(for: request, from: form.finalized())
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 201 else {
            Log.error("sending report failed: \(status)")
            throw status == 413 ? IssueReportError.attachmentTooLarge : IssueReportError.server(status)
        }
        Log.info("report sent")
    }

    private static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    private static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
    }

    private static var device: String {
        "\(Signal.deviceCategory) (\(Signal.deviceModel))"
    }

    private static var system: String {
        let version = ProcessInfo.processInfo.operatingSystemVersionString
            .replacingOccurrences(of: "Version ", with: "")
            .replacingOccurrences(of: "Build ", with: "")
        return "\(Signal.platformName) \(version)"
    }

    @concurrent
    private static func collectLogs() async -> Data? {
        var text = ""
        if Log.isFileLoggingEnabled,
           let logFile = Log.logFile,
           let file = try? String(contentsOf: logFile, encoding: .utf8) {
            text += "=== Unwatched.log ===\n\(file)\n"
        }

        do {
            let store = try OSLogStore(scope: .currentProcessIdentifier)
            let entries = try store.getEntries(matching: NSPredicate(format: "subsystem == %@", appSubsystem))
            let lines = entries
                .compactMap { $0 as? OSLogEntryLog }
                .suffix(5000)
                .map { entry in
                    let time = entry.date.formatted(date: .omitted, time: .standard)
                    return "\(time) [\(entry.level.name)] [\(entry.category)] \(entry.composedMessage)"
                }
            text += "=== This launch ===\n\(Device.versionInfo)\n\n\(lines.joined(separator: "\n"))\n"
        } catch {
            Log.error("collectLogs: \(error)")
        }
        return text.isEmpty ? nil : Data(text.utf8)
    }
}

enum IssueReportError: LocalizedError {
    case attachmentTooLarge
    case attachmentUnreadable
    case server(Int)

    var errorDescription: String? {
        switch self {
        case .attachmentTooLarge: String(localized: "attachmentTooLarge")
        case .attachmentUnreadable: String(localized: "attachmentUnreadable")
        case .server(let status): String(localized: "reportServerError \(status)")
        }
    }
}

private struct MultipartForm {
    private let boundary = "Boundary-\(UUID().uuidString)"
    private var body = Data()

    var contentType: String { "multipart/form-data; boundary=\(boundary)" }

    mutating func addField(_ name: String, _ value: String) {
        addPart("Content-Disposition: form-data; name=\"\(name)\"", Data(value.utf8))
    }

    mutating func addFile(_ name: String, fileName: String, mimeType: String, data: Data) {
        addPart(
            "Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(fileName)\"\r\nContent-Type: \(mimeType)",
            data
        )
    }

    func finalized() -> Data {
        body + Data("--\(boundary)--\r\n".utf8)
    }

    private mutating func addPart(_ headers: String, _ content: Data) {
        body.append(Data("--\(boundary)\r\n\(headers)\r\n\r\n".utf8))
        body.append(content)
        body.append(Data("\r\n".utf8))
    }
}

private extension OSLogEntryLog.Level {
    var name: String {
        switch self {
        case .debug: "Debug"
        case .info: "Info"
        case .notice: "Notice"
        case .error: "Error"
        case .fault: "Fault"
        default: "Log"
        }
    }
}
