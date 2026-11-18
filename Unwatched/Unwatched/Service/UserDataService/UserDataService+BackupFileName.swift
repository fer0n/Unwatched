//
//  UserDataService+BackupFileName.swift
//  Unwatched
//

import Foundation

extension UserDataService {
    private static let manualBackupSuffix = "_m"

    static func getFileName(_ deviceName: String, manual: Bool = false) -> String {
        let dateString = Date().formatted(.iso8601)
        return "\(deviceName)_\(dateString)\(manual ? manualBackupSuffix : "").unwatchedbackup"
    }

    static func isManualBackup(_ url: URL) -> Bool {
        url.deletingPathExtension().lastPathComponent.hasSuffix(manualBackupSuffix)
    }

    static func backupDeviceName(from url: URL) -> String? {
        var name = url.deletingPathExtension().lastPathComponent
        if isManualBackup(url) {
            name.removeLast(manualBackupSuffix.count)
        }
        return name.lastIndex(of: "_").map { String(name[..<$0]) }
    }
}
