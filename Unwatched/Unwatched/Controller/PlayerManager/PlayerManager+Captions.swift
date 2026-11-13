//
//  PlayerManager+Captions.swift
//  Unwatched
//

import Foundation
import UnwatchedShared

extension PlayerManager {
    @MainActor
    private var isCustomUI: Bool {
        PlayerSwitchManager.shared.activeType
            .webPlayerType(embeddingDisabled: embeddingDisabled) == .youtubeCustomUI
    }

    @MainActor
    var showsCustomUICaptionControls: Bool {
        guard !UserDefaults.standard.bool(forKey: Const.disableCaptions),
              let video,
              TranscriptDescriptionSelection.canHaveTranscript(
                video, isCurrentVideo: true, transcriptUrl: transcriptUrl
              ) else { return false }
        return isCustomUI
    }

    @MainActor
    func toggleCustomUICaptions() -> Bool {
        let isOn = !UserDefaults.standard.bool(forKey: Const.customUICaptions)
        UserDefaults.standard.set(isOn, forKey: Const.customUICaptions)
        return isOn
    }

    /// YouTube never sees the intercepted key, so its own players get it passed on.
    @MainActor
    func toggleYouTubeCaptions() {
        guard !UserDefaults.standard.bool(forKey: Const.disableCaptions),
              video != nil,
              PlayerSwitchManager.shared.activeType.usesWebPlayer,
              !isCustomUI else { return }
        WebPlayerBackend.shared.toggleYouTubeCaptions()
    }
}
