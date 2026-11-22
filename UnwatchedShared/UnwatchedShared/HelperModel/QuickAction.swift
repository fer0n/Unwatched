//
//  QuickAction.swift
//  UnwatchedShared
//

/// Raw values are the `UIApplicationShortcutItemType`s in Info.plist.
public enum QuickAction: String, Sendable {
    case playPause = "PlayPause"
    case paste = "Paste"
    case search = "Search"

    /// Set on a cold launch from a quick action, before any view can receive it.
    @MainActor public static var pending: QuickAction?
}
