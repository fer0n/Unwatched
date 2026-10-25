//
//  LogFileWriter.swift
//  Unwatched
//

import Foundation
import OSLog

final class LogFileWriter: @unchecked Sendable {
    private let url: URL
    private let queue = DispatchQueue(label: "com.pentlandFirth.Unwatched.LogFileWriter", qos: .utility)
    private let logger = Logger(subsystem: appSubsystem, category: "FileLogger")
    private let maxSize: UInt64 = 4_000_000
    private let trimmedSize = 2_000_000

    private var handle: FileHandle?
    private var size: UInt64 = 0

    init(url: URL) {
        self.url = url
    }

    func append(_ line: String) {
        queue.async {
            self.write(Data(line.utf8))
        }
    }

    func delete() {
        queue.async {
            self.closeHandle()
            do {
                try FileManager.default.removeItem(at: self.url)
            } catch {
                self.logger.error("Failed to delete log file: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func write(_ data: Data) {
        do {
            let handle = try openHandle()
            try handle.write(contentsOf: data)
            size += UInt64(data.count)
            if size > maxSize {
                try trim()
            }
        } catch {
            closeHandle()
            logger.error("Failed to write log file: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func openHandle() throws -> FileHandle {
        if let handle {
            return handle
        }
        if !FileManager.default.fileExists(atPath: url.path) {
            try header.write(to: url)
        }
        let handle = try FileHandle(forWritingTo: url)
        size = try handle.seekToEnd()
        self.handle = handle
        return handle
    }

    private func trim() throws {
        closeHandle()
        var tail = try Data(contentsOf: url).suffix(trimmedSize)
        if let newline = tail.firstIndex(of: UInt8(ascii: "\n")) {
            tail = tail[tail.index(after: newline)...]
        }
        try (header + Data("[older lines removed]\n".utf8) + tail).write(to: url, options: .atomic)
    }

    private func closeHandle() {
        try? handle?.close()
        handle = nil
    }

    private var header: Data {
        Data("\(Device.versionInfo)\n\n".utf8)
    }
}
