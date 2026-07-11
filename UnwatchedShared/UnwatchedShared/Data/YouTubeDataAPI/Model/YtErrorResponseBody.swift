//
//  YtErrorResponseBody.swift
//  UnwatchedShared
//

import Foundation

public struct YtErrorResponseBody: Decodable {
    public struct Error: Decodable {
        var code: Int
        var message: String
    }
    var error: Error
}
