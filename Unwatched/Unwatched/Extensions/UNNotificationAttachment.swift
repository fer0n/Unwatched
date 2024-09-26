//
//  UNNotificationAttachment.swift
//  Unwatched
//

import UserNotifications
import Foundation
import UIKit
import OSLog

extension UNNotificationAttachment {

    static func create(identifier: String,
                       imageData: Data) -> UNNotificationAttachment? {
        guard let image = UIImage(data: imageData) else {
            Logger.log.info("No imagedata")
            return nil
        }
        let croppedImage = image.croppedYtThumbnail()
        let fileManager = FileManager.default
        let tmpSubFolderName = ProcessInfo.processInfo.globallyUniqueString
        let tmpSubFolderURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(tmpSubFolderName, isDirectory: true)
        do {
            try fileManager.createDirectory(at: tmpSubFolderURL, withIntermediateDirectories: true, attributes: nil)
            let imageFileIdentifier = identifier+".png"
            let fileURL = tmpSubFolderURL.appendingPathComponent(imageFileIdentifier)
            guard let imageData = croppedImage.pngData() else {
                return nil
            }
            try imageData.write(to: fileURL)
            let imageAttachment = try UNNotificationAttachment
                .init(identifier: imageFileIdentifier, url: fileURL, options: [
                    UNNotificationAttachmentOptionsThumbnailClippingRectKey:
                        CGRectCreateDictionaryRepresentation(
                            CGRect(
                                x: 0.006, // <- centers the image (trial and error, don't know why)
                                y: 0,
                                width: 1,
                                height: 1
                            )
                        )
                ])
            return imageAttachment
        } catch {
            print("error " + error.localizedDescription)
        }
        return nil
    }
}
