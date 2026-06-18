import Foundation

// Mirrored from SmartTubeIOSCore/QualityRecoveryPolicy.swift (commit ca2abcb).
// Intentional diffs vs upstream:
//   • `quality` parameter: AppSettings.VideoQuality → Int (Unwatched represents the selected
//     quality as a pixel height, with 0 meaning Auto). `quality != .auto` → `quality != 0`.
// Pure classification logic — no AVFoundation import (error domains are string constants).

private let nsURLErrorDomain = NSURLErrorDomain
private let avFoundationErrorDomain = "AVFoundationErrorDomain"

/// Describes what recovery action the player should take when an `AVPlayerItem`
/// enters the `.failed` state.
enum QualityRecoveryAction: Sendable {
    /// HTTP 403 — re-fetch fresh signed URLs via the exhaustive retry path.
    case retry403Recovery
    /// A specific quality cap failed — revert the selection to Auto and reload.
    case revertToAuto
    /// Auto produced an H.264 decode error on first attempt — reload with a bitrate cap.
    case retryWithH264Cap
    /// Unrecoverable; surface the error to the user.
    case fail(error: Error?)
}

/// Returns the recovery action for a failed `AVPlayerItem`.
///
/// Priority (highest first):
/// 1. HTTP 403 → `.retry403Recovery`
/// 2. A specific quality (non-Auto) was requested → `.revertToAuto`
/// 3. H.264 decode error on first attempt → `.retryWithH264Cap`
/// 4. All other cases → `.fail(error:)`
///
/// - Parameters:
///   - error: The `NSError` from `AVPlayerItem.error`.
///   - quality: The quality height in effect when the item failed. `0` means Auto (no cap).
///   - hasAppliedH264Cap: `true` if the H.264 bitrate cap has already been tried.
func qualityRecoveryAction(
    for error: NSError,
    quality: Int,
    hasAppliedH264Cap: Bool
) -> QualityRecoveryAction {
    let is403 = error.domain == nsURLErrorDomain && error.code == -1102
    let isH264DecodeError = error.domain == avFoundationErrorDomain && error.code == -11833
    if is403 { return .retry403Recovery }
    if quality != 0 { return .revertToAuto }
    if !hasAppliedH264Cap && isH264DecodeError { return .retryWithH264Cap }
    return .fail(error: error)
}
