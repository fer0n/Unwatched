//
//  WelcomeBack.swift
//  Unwatched
//

import Foundation
import OSLog
import UnwatchedShared

struct BackupSummary: Decodable {
    let deviceId: String?
    let deviceKind: SyncDeviceKind
    let settings: [String: AnyCodable]?

    var syncWasOn: Bool {
        switch settings?[Const.enableIcloudSync]?.value {
        case let flag as Bool: flag
        case let flag as Int: flag != 0
        default: false
        }
    }

    private enum CodingKeys: String, CodingKey {
        case deviceId, deviceKind, settings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        deviceId = try? container.decodeIfPresent(String.self, forKey: .deviceId)
        deviceKind = SyncDeviceKind(stored: try? container.decodeIfPresent(String.self, forKey: .deviceKind))
        settings = (try? container.decodeIfPresent([String: Lossy<AnyCodable>].self, forKey: .settings))?
            .compactMapValues(\.value)
    }
}

struct WelcomeBack {
    enum Offer: Equatable {
        case syncWasOn
        case otherDevice(SyncDeviceKind)
        case sameDevice
    }

    let offer: Offer
    let backupURL: URL
    let backupDate: Date
    let backupDeviceName: String
    private let backupDeviceId: String?
    private let settings: [String: AnyCodable]?

    private static let handledKey = "welcomeBackHandled"

    static var isHandled: Bool {
        get { UserDefaults.standard.bool(forKey: handledKey) }
        set { UserDefaults.standard.set(newValue, forKey: handledKey) }
    }

    @MainActor
    static func find() async -> WelcomeBack? {
        guard !isHandled,
              !UserDefaults.standard.bool(forKey: Const.enableIcloudSync),
              FileManager.default.ubiquityIdentityToken != nil else {
            return nil
        }
        SyncHandoff.refresh()
        guard let url = await IcloudBackupQuery.newestDownloadedBackup(timeout: .seconds(30)),
              let summary = await readSummary(url) else {
            return nil
        }
        return WelcomeBack(
            offer: offer(for: summary),
            backupURL: url,
            backupDate: url.creationDate,
            backupDeviceName: deviceName(from: url),
            backupDeviceId: summary.deviceId,
            settings: summary.settings
        )
    }

    @MainActor
    private static func offer(for summary: BackupSummary) -> Offer {
        if summary.syncWasOn || SyncHandoff.isSyncOnElsewhere {
            return .syncWasOn
        }
        guard let deviceId = summary.deviceId, deviceId != DeviceIdentity.id else {
            return .sameDevice
        }
        return .otherDevice(summary.deviceKind)
    }

    private static func readSummary(_ url: URL) async -> BackupSummary? {
        await Task.detached(priority: .userInitiated) {
            do {
                return try UserDataService.decodeBackupSummary(Data(contentsOf: url))
            } catch {
                Log.data.error("welcomeBack: couldn't read backup: \(error)")
                return nil
            }
        }.value
    }

    private static func deviceName(from url: URL) -> String {
        let name = url.deletingPathExtension().lastPathComponent
        return name.split(separator: "_").first.map(String.init) ?? name
    }
}

@MainActor
extension WelcomeBack {
    var analyticsName: String {
        switch offer {
        case .syncWasOn: "syncWasOn"
        case .otherDevice: "otherDevice"
        case .sameDevice: "sameDevice"
        }
    }

    func turnOnSync() {
        UserDataService.restoreSettings(settings, includeSynced: false)
        UserDefaults.standard.set(true, forKey: Const.enableIcloudSync)
        SyncHandoff.publishSyncState(true)
        if case .otherDevice = offer, let backupDeviceId {
            SyncHandoff.requestSync(on: backupDeviceId)
        }
        Self.isHandled = true
        Signal.onboardingStep("welcomeBack", parameters: ["offer": analyticsName, "action": "sync"])
    }

    func restoreSettings() {
        UserDataService.restoreSettings(settings, includeSynced: false)
        finishRestore(action: "settingsOnly")
    }

    func restoreLibrary() async throws {
        let url = backupURL
        let backup = try await Task.detached(priority: .userInitiated) {
            try UserDataService.decodeBackup(Data(contentsOf: url))
        }.value
        try UserDataService.restore(backup, includeSynced: false)
        finishRestore(action: "restore")
    }

    private func finishRestore(action: String) {
        UserDefaults.standard.set(false, forKey: Const.enableIcloudSync)
        SyncHandoff.declinePendingRequest()
        Self.isHandled = true
        Signal.onboardingStep("welcomeBack", parameters: ["offer": analyticsName, "action": action])
    }

    func dismiss() {
        Self.isHandled = true
        Signal.onboardingStep("welcomeBack", parameters: ["offer": analyticsName, "action": "dismiss"])
    }
}
