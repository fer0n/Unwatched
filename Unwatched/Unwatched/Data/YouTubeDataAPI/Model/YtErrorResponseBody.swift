//
//  YtErrorResponseBody.swift
//  Unwatched
//

import Foundation

struct YtErrorResponseBody: Decodable {
    struct Error: Decodable {
        var code: Int
        var message: String
    }
    var error: Error
}
