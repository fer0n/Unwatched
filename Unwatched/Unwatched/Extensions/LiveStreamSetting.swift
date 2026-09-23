//
//  LiveStreamSetting.swift
//  Unwatched
//

import UnwatchedShared

extension LiveStreamSetting {

    func description(defaultSetting: String) -> String {
        self == .defaultSetting
            ? String(localized: "defaultLiveStreamSetting \(defaultSetting)")
            : description
    }

    var description: String {
        switch self {
        case .show: String(localized: "showLiveStreams")
        case .hide: String(localized: "hideLiveStreams")
        case .defaultSetting: String(localized: "useDefault")
        }
    }

    var systemName: String? {
        switch self {
        case .show: "dot.radiowaves.left.and.right"
        case .hide: "eye.slash.fill"
        case .defaultSetting: nil
        }
    }

    static var defaultHides: Bool {
        let raw = CloudKeyValueStore.shared.longLong(forKey: Const.defaultLiveStreamSetting)
        return LiveStreamSetting(rawValue: Int(raw)) == .hide
    }

    func shouldHide(_ defaultHides: Bool? = nil) -> Bool {
        switch self {
        case .show: false
        case .hide: true
        case .defaultSetting: defaultHides ?? Self.defaultHides
        }
    }
}
