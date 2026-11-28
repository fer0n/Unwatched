//
//  PlayerManager+Captions.swift
//  Unwatched
//

import Foundation
import UnwatchedShared

extension PlayerManager {
    @MainActor
    var showsCaptionControls: Bool {
        guard captions != nil, PlayerSwitchManager.shared.activeType.usesWebPlayer, let video else { return false }
        return TranscriptDescriptionSelection.canHaveTranscript(
            video, isCurrentVideo: true, transcriptUrl: transcriptUrl
        )
    }

    @MainActor
    var captionsOn: Bool {
        captions?.selected != nil
    }

    /// Empty turns them off.
    @MainActor
    func setCaptions(_ languageCode: String) {
        WebPlayerBackend.shared.setCaptions(languageCode)
    }

    @MainActor
    @discardableResult
    func toggleCaptions() -> Bool {
        let isOn = !captionsOn
        WebPlayerBackend.shared.toggleCaptions()
        return isOn
    }
}
