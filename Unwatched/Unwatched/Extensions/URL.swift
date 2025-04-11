//
//  File.swift
//  Unwatched
//

import SwiftUI

extension URL {
    init(staticString: StaticString) {
        guard let url = Self(string: "\(staticString)") else {
            fatalError("Invalid static URL string: \(staticString)")
        }

        self = url
    }

    var creationDate: Date {
        return (try? resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
    }
}
