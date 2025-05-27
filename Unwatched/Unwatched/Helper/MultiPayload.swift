//
//  MultiPayload.swift
//  Unwatched
//

import SwiftUI
import UniformTypeIdentifiers
import UnwatchedShared

struct MultiPayload: Transferable {
    enum PayloadContent {
        case text(String)
        case url(URL)
    }

    let content: PayloadContent

    static var transferRepresentation: some TransferRepresentation {
        // Handle String transfers
        DataRepresentation(
            contentType: UTType.plainText,
            exporting: { payload -> Data in
                switch payload.content {
                case .text(let string):
                    return Data(string.utf8)
                case .url(let url):
                    return Data(url.absoluteString.utf8)
                }
            },
            importing: { data in
                guard let string = String(data: data, encoding: .utf8) else {
                    throw TransferError.stringConversionFailed
                }
                return MultiPayload(content: .text(string))
            }
        )

        // Handle URL transfers
        DataRepresentation(
            contentType: UTType.url,
            exporting: { payload -> Data in
                switch payload.content {
                case .text(let string):
                    if let url = URL(string: string) {
                        return Data(url.absoluteString.utf8)
                    } else {
                        return Data(string.utf8)
                    }
                case .url(let url):
                    return Data(url.absoluteString.utf8)
                }
            },
            importing: { data in
                if let plistObj = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) {
                    // Handle property list format (usually an array with the URL as first element)
                    if let urlArray = plistObj as? [Any],
                       let urlString = urlArray.first as? String,
                       !urlString.isEmpty {
                        if let url = URL(string: urlString) {
                            return MultiPayload(content: .url(url))
                        }
                    }
                }
                throw TransferError.urlConversionFailed
            }
        )
    }

    enum TransferError: Error {
        case stringConversionFailed
        case urlConversionFailed
    }
}
