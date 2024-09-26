//
//  AsyncSharableUrl.swift
//  Unwatched
//

import Foundation
import SwiftUI

struct AsyncSharableUrls: Transferable {
    let getUrls: () async -> [(title: String, link: URL?)]
    @Binding var isLoading: Bool

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .plainText) { item in
            item.isLoading = true
            let urls = await item.getUrls()
            let textUrls = urls
                .map { "\($0.title)\n\($0.link?.absoluteString ?? "...")\n" }
                .joined(separator: "\n")
            let data = textUrls.data(using: .utf8)
            if let data = data {
                item.isLoading = false
                return data
            } else {
                fatalError()
            }
            item.isLoading = false
        }
    }
}

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

struct IdentifiableString: Identifiable {
    let id = UUID()
    let str: String
}
