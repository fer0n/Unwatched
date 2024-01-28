//
//  Exportable.swift
//  Unwatched
//

import Foundation

protocol Exportable {
    associatedtype ExportType

    var toExport: ExportType? { get }
}
