//
//  SyncDeviceKind.swift
//  UnwatchedShared
//

import Foundation

public enum SyncDeviceKind: String, Sendable, CaseIterable {
    case iPhone, iPad, mac, vision, tv, watch, other

    public init(stored: Any?) {
        self = (stored as? String).flatMap(SyncDeviceKind.init(rawValue:)) ?? .other
    }

    public static let current: SyncDeviceKind = {
        #if os(macOS) || targetEnvironment(macCatalyst)
        return .mac
        #elseif os(visionOS)
        return .vision
        #elseif os(tvOS)
        return .tv
        #elseif os(watchOS)
        return .watch
        #else
        if ProcessInfo.processInfo.isiOSAppOnMac { return .mac }
        let model = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? hardwareModel()
        if model.hasPrefix("iPhone") { return .iPhone }
        if model.hasPrefix("iPad") { return .iPad }
        return .other
        #endif
    }()

    private static func hardwareModel() -> String {
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
    }

    public var productName: String? {
        switch self {
        case .iPhone: "iPhone"
        case .iPad: "iPad"
        case .mac: "Mac"
        case .vision: "Apple Vision Pro"
        case .tv: "Apple TV"
        case .watch: "Apple Watch"
        case .other: nil
        }
    }

    public var systemImage: String {
        switch self {
        case .iPhone: "iphone"
        case .iPad: "ipad"
        case .mac: "laptopcomputer"
        case .vision: "vision.pro"
        case .tv: "appletv"
        case .watch: "applewatch"
        case .other: "macbook.and.iphone"
        }
    }
}
