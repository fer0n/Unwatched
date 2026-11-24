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

    private static let handledKey = Const.welcomeBackHandled
    private static let maxSettingsAge: TimeInterval = 180 * 24 * 60 * 60

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
        let query = IcloudBackupQuery()
        defer { query.stop() }
        guard let newest = await query.newestDownloadedBackup(until: .now + .seconds(30)),
              let summary = await readSummary(newest.url) else {
            return nil
        }
        return WelcomeBack(
            offer: offer(for: summary),
            backupURL: newest.url,
            backupDate: newest.date,
            backupDeviceName: deviceName(from: newest.url),
            backupDeviceId: summary.deviceId,
            settings: await preferredSettings(newest: newest, newestSummary: summary, query: query)
        )
    }

    @MainActor
    private static func preferredSettings(
        newest: IcloudBackup,
        newestSummary: BackupSummary,
        query: IcloudBackupQuery
    ) async -> [String: AnyCodable]? {
        let deadline = ContinuousClock.now + .seconds(10)
        let candidates = settingsCandidates(
            in: query.backups(),
            newest: newest,
            currentKind: .current,
            currentDeviceName: Device.deviceName
        )
        for candidate in candidates {
            let summary: BackupSummary?
            if candidate.url == newest.url {
                summary = newestSummary
            } else if await query.download(candidate, until: deadline) {
                summary = await readSummary(candidate.url)
            } else {
                summary = nil
            }
            if let summary, summary.settings?.isEmpty == false, isFromCurrentDeviceFamily(
                summary,
                backupDeviceName: deviceName(from: candidate.url),
                currentDeviceId: DeviceIdentity.id,
                currentKind: .current,
                currentDeviceName: Device.deviceName
            ) {
                return summary.settings
            }
        }
        return newestSummary.settings
    }

    static func settingsCandidates(
        in backups: [IcloudBackup],
        newest: IcloudBackup,
        currentKind: SyncDeviceKind,
        currentDeviceName: String
    ) -> [IcloudBackup] {
        let oldestAllowed = newest.date.addingTimeInterval(-maxSettingsAge)
        let otherKindNames = Set(SyncDeviceKind.allCases.filter { $0 != currentKind }.compactMap(\.productName))
        let eligible = backups.filter { backup in
            backup.date >= oldestAllowed
                && (backup.url == newest.url || !otherKindNames.contains(deviceName(from: backup.url)))
        }
        let newestPerDevice = Dictionary(grouping: eligible) {
            deviceName(from: $0.url)
        }.compactMapValues { $0.max { $0.date < $1.date } }

        return newestPerDevice
            .sorted { lhs, rhs in
                let lhsIsCurrent = lhs.key == currentDeviceName
                let rhsIsCurrent = rhs.key == currentDeviceName
                return lhsIsCurrent != rhsIsCurrent ? lhsIsCurrent : lhs.value.date > rhs.value.date
            }
            .map(\.value)
    }

    static func isFromCurrentDeviceFamily(
        _ summary: BackupSummary,
        backupDeviceName: String,
        currentDeviceId: String,
        currentKind: SyncDeviceKind,
        currentDeviceName: String
    ) -> Bool {
        if summary.deviceId == currentDeviceId {
            return true
        }
        let hasNoDeviceKind = summary.deviceKind == .other
        return hasNoDeviceKind ? backupDeviceName == currentDeviceName : summary.deviceKind == currentKind
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

    static func deviceName(from url: URL) -> String {
        UserDataService.backupDeviceName(from: url) ?? url.deletingPathExtension().lastPathComponent
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
        UserDataService.restoreSettings(settings, includeSynced: false)
        try UserDataService.restoreVideoData(from: backup)
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
