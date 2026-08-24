//
//  URLResponse.swift
//  UnwatchedShared
//

import Foundation

public extension URLResponse {
    /// True for a 2xx status, and for anything that isn't an HTTP response.
    var isSuccessfulHttp: Bool {
        guard let http = self as? HTTPURLResponse else { return true }
        return (200...299).contains(http.statusCode)
    }
}
