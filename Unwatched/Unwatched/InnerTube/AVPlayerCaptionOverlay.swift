#if !os(macOS)
import SwiftUI
import OSLog
import UnwatchedShared

struct PlayerCaptionOverlay: View {
    @Environment(PlayerManager.self) var player
    @AppStorage(Const.playerType) private var playerType: PlayerTypeSetting = .youtubeEmbedded

    @State private var displayedLines: [String] = []
    @State private var trackFetchTask: Task<Void, Never>?
    @State private var vttFetchTask: Task<Void, Never>?

    private var isNative: Bool { playerType == .native }

    var body: some View {
        VStack(spacing: 2) {
            ForEach(displayedLines, id: \.self) { line in
                Text(line)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.8), radius: 1, x: 0, y: 1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .fixedSize()
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            }
        }
        .padding(.bottom, 10)
        // Update display whenever the active cue changes.
        // For native: written by the 100 ms AVPlayer time observer.
        // For custom UI: written by the onChange(of: currentTime) below.
        .onChange(of: player.currentCaptionCue?.startTime) { _, _ in
            withAnimation(.easeOut(duration: 0.25)) {
                displayedLines = player.currentCaptionCue?.text.components(separatedBy: "\n") ?? []
            }
        }
        // Custom UI: JS currentTime updates drive cue lookup.
        .onChange(of: player.currentTime) { _, t in
            guard !isNative, let t, player.selectedCaptionTrackId != nil,
                  !player.captionCues.isEmpty else { return }
            let cue = player.findCaptionCue(at: t + 0.15)
            if cue?.startTime != player.currentCaptionCue?.startTime {
                player.currentCaptionCue = cue
            }
        }
        // Custom UI: fetch caption tracks from InnerTube when the video changes.
        .onChange(of: player.video?.youtubeId, initial: true) { _, videoId in
            guard !isNative else { return }
            player.availableCaptionTracks = []
            player.selectedCaptionTrackId = nil
            player.captionCues = []
            player.currentCaptionCue = nil
            trackFetchTask?.cancel()
            vttFetchTask?.cancel()
            guard let videoId else { return }
            trackFetchTask = Task {
                guard let info = try? await InnerTubeAPI().fetchPlayerInfo(videoId: videoId),
                      !Task.isCancelled else { return }
                await MainActor.run {
                    player.availableCaptionTracks = info.captionTracks
                }
            }
        }
        // Custom UI: fetch VTT when the user picks a track.
        .onChange(of: player.selectedCaptionTrackId) { _, trackId in
            guard !isNative else { return }
            vttFetchTask?.cancel()
            vttFetchTask = nil
            player.captionCues = []
            player.currentCaptionCue = nil
            guard let trackId,
                  let track = player.availableCaptionTracks.first(where: { $0.id == trackId }) else { return }
            let url = track.baseURL
            vttFetchTask = Task {
                do {
                    let cues = try await WebVTTParser().fetchCues(from: url)
                    guard !Task.isCancelled else { return }
                    await MainActor.run { player.captionCues = cues }
                } catch {
                    Log.error("Caption VTT fetch failed (custom UI): \(error)")
                }
            }
        }
    }
}
#endif
