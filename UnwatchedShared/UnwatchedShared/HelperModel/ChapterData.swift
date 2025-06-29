//
//  ChapterData.swift
//  UnwatchedShared
//

public protocol ChapterData {
    var startTime: Double { get }
    var endTime: Double? { get }
    var isActive: Bool { get }
}
