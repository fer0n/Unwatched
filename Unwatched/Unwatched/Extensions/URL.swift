//
//  File.swift
//  Unwatched
//

import SwiftUI

extension URL {
    var creationDate: Date {
        return (try? resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
    }
}
