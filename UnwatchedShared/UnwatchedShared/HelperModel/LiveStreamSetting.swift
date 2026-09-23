//
//  LiveStreamSetting.swift
//  UnwatchedShared
//

@frozen public enum LiveStreamSetting: Int, Codable, CaseIterable, Sendable {
    case show
    case hide
    case defaultSetting
}
