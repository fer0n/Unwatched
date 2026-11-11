//
//  IssueReportService.swift
//  Unwatched
//

import Foundation
import OSLog
import UnwatchedShared

enum IssueReportService {
    static func prepareLogs() async -> Data {
        await collectLogs(state: await currentState())
    }

    static func send(
        message: String,
        contact: String,
        logs: Data?,
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
        if let logs {
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

    @MainActor
    private static func currentState() async -> String {
        let player = PlayerManager.shared
        let activeType = PlayerSwitchManager.shared.activeType
        var lines = [
            "playerType: \(PlayerTypeSetting.stored.rawValue), active: \(activeType.rawValue)",
            "nativeFallback: \(player.nativeFallbackActive), embeddingDisabled: \(player.embeddingDisabled)",
            "video: \(player.video?.youtubeId ?? "none"), playing: \(player.isPlaying), speed: \(player.playbackSpeed)",
            "aspectRatio: \(player.videoAspectRatio)"
        ]
        if activeType == .native {
            lines.append("quality: \(player.selectedVideoQuality == 0 ? "auto" : "\(player.selectedVideoQuality)p")")
        } else if let webView = WebPlayerBackend.shared.webView {
            let resolution = try? await webView.evaluateJavaScript(videoResolutionScript) as? String
            lines.append("view: \(Int(webView.bounds.width))x\(Int(webView.bounds.height)), video: \(resolution ?? "?")")
        }
        let settings = UserDataService.getNonDefaultSettings(prefixValue: nil)
            .sorted { $0.key < $1.key }
            .map { "\($0.key): \($0.value)" }
        return """
            === Player ===
            \(lines.joined(separator: "\n"))

            === Changed settings ===
            \(settings.joined(separator: "\n"))

            """
    }

    private static let videoResolutionScript = """
        (() => {
            const video = document.querySelector('video');
            return video ? `${video.videoWidth}x${video.videoHeight}` : null;
        })()
        """

    @concurrent
    private static func collectLogs(state: String) async -> Data {
        var text = state
        if Log.isFileLoggingEnabled,
           let logFile = Log.logFile,
           let file = try? String(contentsOf: logFile, encoding: .utf8) {
            text += "=== Unwatched.log ===\n\(file)\n"
        }

        do {
            let store = try OSLogStore(scope: .currentProcessIdentifier)
            let entries = try store.getEntries(matching: NSPredicate(format: "subsystem == %@", appSubsystem))
            if Task.isCancelled { return Data() }
            let lines = withoutInnerTubeFlood(entries.compactMap { $0 as? OSLogEntryLog })
                .map { entry in
                    let time = entry.date.formatted(date: .omitted, time: .standard)
                    return "\(time) [\(entry.level.name)] [\(entry.category)] \(entry.composedMessage)"
                }
            text += "=== This launch ===\n\(Device.versionInfo)\n\n\(lines.joined(separator: "\n"))\n"
        } catch {
            Log.error("collectLogs: \(error)")
        }
        return Data(text.utf8)
    }

    private static func withoutInnerTubeFlood(_ entries: [OSLogEntryLog]) -> [OSLogEntryLog] {
        var innerTubeLeft = 1000
        return entries.reversed()
            .filter { entry in
                guard entry.category == Log.innerTube.category, entry.level == .notice else { return true }
                innerTubeLeft -= 1
                return innerTubeLeft >= 0
            }
            .prefix(5000)
            .reversed()
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
