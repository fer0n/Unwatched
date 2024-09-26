//
//  Exportable.swift
//  Unwatched
//

import Foundation

public protocol Exportable {
    associatedtype ExportType

    var toExport: ExportType? { get }
}
