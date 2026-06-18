import Foundation

// MARK: - AudioTrack

/// A single audio rendition from an HLS manifest, exposed via AVMediaSelectionGroup.
/// AVMediaSelectionOption itself is not Sendable, so we snapshot the data we need
/// into this struct at load time; the actual option is kept in PlaybackViewModel.
struct AudioTrack: Identifiable, Hashable, Sendable {
    /// BCP 47 language tag from the HLS rendition (e.g. "en", "es-419", "fr").
    let id: String
    /// Localised display name (e.g. "English", "Spanish", "French").
    let name: String
    /// ISO 639-1 / BCP 47 language code — same value as `id` for #EXT-X-MEDIA tracks.
    let languageCode: String
    /// `true` when this is the HLS `DEFAULT=YES` rendition (the original audio).
    let isOriginal: Bool
    /// The `YT-EXT-AUDIO-CONTENT-ID` value used to filter HLS variants via the proxy.
    /// `nil` for tracks sourced from `#EXT-X-MEDIA` groups (AVMediaSelectionGroup path)
    /// and for the synthetic "Original" entry added when the original-audio variant
    /// lacks a `YT-EXT-AUDIO-CONTENT-ID` attribute. When `nil`, the proxy keeps
    /// variants that have *no* `YT-EXT-AUDIO-CONTENT-ID` (i.e. the original stream).
    let contentID: String?

    init(id: String, name: String, languageCode: String, isOriginal: Bool,
         contentID: String? = nil) {
        self.id = id
        self.name = name
        self.languageCode = languageCode
        self.isOriginal = isOriginal
        self.contentID = contentID
    }
}
