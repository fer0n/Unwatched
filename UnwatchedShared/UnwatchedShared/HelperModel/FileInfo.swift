//
//  FileInfo.swift
//  Unwatched
//

import Foundation

public struct FileInfo {
    public init(deviceName: String?, dateString: String?, fileSizeString: String?, isManual: Bool) {
        self.deviceName = deviceName
        self.dateString = dateString
        self.fileSizeString = fileSizeString
        self.isManual = isManual
    }

    public let deviceName: String?
    public let dateString: String?
    public let fileSizeString: String?
    public let isManual: Bool
}
