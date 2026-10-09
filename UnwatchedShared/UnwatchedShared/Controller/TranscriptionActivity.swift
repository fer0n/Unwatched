//
//  TranscriptionActivity.swift
//  UnwatchedShared
//

import Foundation

@MainActor
@Observable
public final class TranscriptionActivity {
    public static let shared = TranscriptionActivity()

    public var youtubeId: String?

    private init() { }
}
