//
//  WelcomeBackSettingsTests.swift
//  UnwatchedUITests
//

import XCTest
import UnwatchedShared

// swiftlint:disable all
class WelcomeBackSettingsTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let day: TimeInterval = 24 * 60 * 60

    private func backup(_ name: String, daysOld: Double, manual: Bool = false) -> IcloudBackup {
        let date = now.addingTimeInterval(-daysOld * day)
        let suffix = manual ? "_m" : ""
        let url = URL(fileURLWithPath: "/Backups/\(name)_\(date.formatted(.iso8601))\(suffix).unwatchedbackup")
        return IcloudBackup(url: url, date: date)
    }

    private func summary(deviceId: String? = nil, kind: String? = nil) throws -> BackupSummary {
        let fields = ["deviceId": deviceId, "deviceKind": kind].compactMapValues { $0 }
        return try JSONDecoder().decode(BackupSummary.self, from: JSONEncoder().encode(fields))
    }

    private func candidates(in backups: [IcloudBackup], newest: IcloudBackup) -> [IcloudBackup] {
        WelcomeBack.settingsCandidates(
            in: backups,
            newest: newest,
            currentKind: .iPhone,
            currentDeviceName: "iPhone"
        )
    }

    private func isMatch(_ summary: BackupSummary, name: String = "other") -> Bool {
        WelcomeBack.isFromCurrentDeviceFamily(
            summary,
            backupDeviceName: name,
            currentDeviceId: "this",
            currentKind: .iPhone,
            currentDeviceName: "iPhone"
        )
    }

    func testDeviceNameSurvivesUnderscoresAndManualSuffix() {
        XCTAssertEqual(WelcomeBack.deviceName(from: backup("iPhone", daysOld: 0).url), "iPhone")
        XCTAssertEqual(WelcomeBack.deviceName(from: backup("my_mac", daysOld: 0, manual: true).url), "my_mac")
    }

    func testOnlyTheFilenameSuffixMarksABackupAsManual() {
        XCTAssertTrue(UserDataService.isManualBackup(backup("iPhone", daysOld: 0, manual: true).url))
        XCTAssertTrue(UserDataService.isManualBackup(backup("my_mac", daysOld: 0, manual: true).url))
        XCTAssertFalse(UserDataService.isManualBackup(backup("my_mac", daysOld: 0).url))
    }

    func testCandidatesPutThisDeviceFirstAndKeepNewestPerDevice() {
        let newest = backup("iPad", daysOld: 0)
        let customNamedMac = backup("Studio", daysOld: 2)
        let phone = backup("iPhone", daysOld: 5)
        let olderPhone = backup("iPhone", daysOld: 9)
        XCTAssertEqual(
            candidates(in: [olderPhone, customNamedMac, newest, phone], newest: newest),
            [phone, newest, customNamedMac]
        )
    }

    func testCandidatesSkipBackupsNamedAfterAnotherDeviceKind() {
        let newest = backup("iPhone", daysOld: 0)
        XCTAssertEqual(
            candidates(in: [newest, backup("iPad", daysOld: 1), backup("Mac", daysOld: 2)], newest: newest),
            [newest]
        )
    }

    func testCandidatesDropBackupsFarOlderThanTheNewest() {
        let newest = backup("iPad", daysOld: 0)
        XCTAssertEqual(candidates(in: [newest, backup("iPhone", daysOld: 181)], newest: newest), [newest])
    }

    func testFamilyMatching() throws {
        XCTAssertTrue(isMatch(try summary(deviceId: "this", kind: "iPad")))
        XCTAssertTrue(isMatch(try summary(deviceId: "phone2", kind: "iPhone")))
        XCTAssertFalse(isMatch(try summary(deviceId: "pad", kind: "iPad"), name: "iPhone"))
    }

    func testBackupWithoutDeviceInfoMatchesByName() throws {
        XCTAssertTrue(isMatch(try summary(), name: "iPhone"))
        XCTAssertFalse(isMatch(try summary(), name: "iPad"))
    }
}

// swiftlint:enable all
