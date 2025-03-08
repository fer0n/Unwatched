//
//  ClipboardService.swift
//  Unwatched
//

#if os(macOS)
import AppKit
#else
import UIKit
import UniformTypeIdentifiers
#endif

struct ClipboardService {
    static func get() -> String? {
        #if os(iOS)
        return UIPasteboard.general.string
        #elseif os(macOS)
        return NSPasteboard.general.string(forType: .string)
        #else
        return nil
        #endif
    }

    static func set(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.setValue(
            text,
            forPasteboardType: UTType.plainText.identifier
        )
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}
