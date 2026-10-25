//
//  IssueReportAttachment.swift
//  Unwatched
//

import AVFoundation
import CoreTransferable
import ImageIO
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct IssueReportAttachment {
    private static let workerKVValueLimit = 24 * 1024 * 1024
    private static let videoPresets = [
        AVAssetExportPresetHEVC1920x1080,
        AVAssetExportPreset1280x720,
        AVAssetExportPreset960x540
    ]

    let data: Data
    let mimeType: String
    let fileName: String
    let thumbnail: CGImage?

    static func load(_ item: PhotosPickerItem) async throws -> IssueReportAttachment {
        if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
            guard let movie = try await item.loadTransferable(type: PickedMovie.self) else {
                throw IssueReportError.attachmentUnreadable
            }
            return try await video(at: movie.url)
        }
        guard let data = try await item.loadTransferable(type: Data.self) else {
            throw IssueReportError.attachmentUnreadable
        }
        return try await image(data, type: item.supportedContentTypes.first)
    }

    @concurrent
    private static func image(_ data: Data, type: UTType?) async throws -> IssueReportAttachment {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw IssueReportError.attachmentUnreadable
        }
        let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 132
        ] as CFDictionary)

        if let type, type.conforms(to: .png) || type.conforms(to: .jpeg) {
            return try checked(IssueReportAttachment(
                data: data,
                mimeType: type.preferredMIMEType ?? "image/png",
                fileName: "screenshot.\(type.preferredFilenameExtension ?? "png")",
                thumbnail: thumbnail
            ))
        }

        let jpeg = NSMutableData()
        guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let destination = CGImageDestinationCreateWithData(jpeg, UTType.jpeg.identifier as CFString, 1, nil)
        else {
            throw IssueReportError.attachmentUnreadable
        }
        let options = [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary
        CGImageDestinationAddImage(destination, image, options)
        guard CGImageDestinationFinalize(destination) else { throw IssueReportError.attachmentUnreadable }
        return try checked(IssueReportAttachment(
            data: jpeg as Data,
            mimeType: "image/jpeg",
            fileName: "screenshot.jpg",
            thumbnail: thumbnail
        ))
    }

    @concurrent
    private static func video(at url: URL) async throws -> IssueReportAttachment {
        defer { try? FileManager.default.removeItem(at: url) }
        let asset = AVURLAsset(url: url)
        for preset in videoPresets {
            guard let session = AVAssetExportSession(asset: asset, presetName: preset) else { continue }
            let output = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mp4")
            defer { try? FileManager.default.removeItem(at: output) }
            guard (try? await session.export(to: output, as: .mp4)) != nil,
                  let data = try? Data(contentsOf: output),
                  data.count <= workerKVValueLimit else { continue }
            return IssueReportAttachment(data: data, mimeType: "video/mp4", fileName: "recording.mp4", thumbnail: nil)
        }
        throw IssueReportError.attachmentTooLarge
    }

    private static func checked(_ attachment: IssueReportAttachment) throws -> IssueReportAttachment {
        guard attachment.data.count <= workerKVValueLimit else { throw IssueReportError.attachmentTooLarge }
        return attachment
    }
}

private struct PickedMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let copy = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(received.file.pathExtension)
            try FileManager.default.copyItem(at: received.file, to: copy)
            return PickedMovie(url: copy)
        }
    }
}
