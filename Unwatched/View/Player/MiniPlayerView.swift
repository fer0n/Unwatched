//
//  MiniPlayerView.swift
//  Unwatched
//

import SwiftUI

struct MiniPlayerView: View {
    @Environment(NavigationManager.self) var navManager
    @Environment(PlayerManager.self) var player
    @Environment(SheetPositionReader.self) var sheetPos

    var body: some View {
        let hideMiniPlayer = (
            (navManager.showMenu || navManager.showDescriptionDetail)
                && sheetPos.swipedBelow
        ) || (navManager.showMenu == false && navManager.showDescriptionDetail == false)

        VStack {
            HStack(alignment: .center) {
                if let video = player.video {
                    CachedImageView(video: video) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 89, height: 50)
                            .clipped()
                    } placeholder: {
                        Color.backgroundColor
                    }
                    .aspectRatio(16/9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    Text(video.title)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        player.isPlaying.toggle()
                    } label: {
                        Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .resizable()
                            .frame(width: 30, height: 30)
                            .accentColor(.myAccentColor)
                            .contentTransition(.symbolEffect(.replace, options: .speed(7)))
                    }
                }
            }
            .onTapGesture {
                navManager.showMenu = false
                navManager.showDescriptionDetail = false
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
            .frame(height: Const.playerAboveSheetHeight)
            Spacer()
        }
        .background(Color.backgroundColor)
        .opacity(hideMiniPlayer ? 0 : 1)
        .animation(.bouncy(duration: 0.5), value: hideMiniPlayer)
    }
}

#Preview {
    MiniPlayerView()
        .modelContainer(DataController.previewContainer)
        .environment(NavigationManager.getDummy())
}
