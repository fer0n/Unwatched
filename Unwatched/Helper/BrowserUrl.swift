//
//  BrowserUrl.swift
//  Unwatched
//

import Foundation

enum BrowserUrl: Identifiable {
    case youtubeStartPage
    case url(_ url: String)

    var id: String {
        getUrlString
    }

    var getUrlString: String {
        switch self {
        case .youtubeStartPage:
            return UrlService.youtubeStartPageString
        case .url(let url):
            return url
        }
    }

    var getUrl: URL? {
        URL(string: getUrlString)
    }
}
