import SwiftUI
import UnwatchedShared

struct MiniPlayerLayout<Content: View>: View {
    @Environment(PlayerManager.self) var player
    var hideMiniPlayer: Bool
    var handleMiniPlayerTap: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack {
            content()
            if !hideMiniPlayer {
                MiniPlayerContent(
                    videoTitle: player.video?.title,
                    handleMiniPlayerTap: handleMiniPlayerTap
                )
            }
        }
        .animation(.bouncy(duration: 0.4), value: hideMiniPlayer)
        .frame(height: !hideMiniPlayer ? Const.playerAboveSheetHeight : nil)
    }
}
