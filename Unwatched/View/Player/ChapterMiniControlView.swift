//
//  ChapterMiniControlView.swift
//  Unwatched
//

import SwiftUI

struct ChapterMiniControlView: View {
    @Environment(PlayerManager.self) var player
    @State var showChapterSelection = false

    var body: some View {
        if let chapter = player.currentChapter {
            HStack {
                Button(action: player.previousChapter) {
                    Image(systemName: "backward.end.fill")
                }
                Spacer()
                Text(chapter.title)
                    .lineLimit(1)
                    .padding()
                Spacer()
                Button(action: player.nextChapter) {
                    Image(systemName: "forward.end.fill")
                }
            }
            .onTapGesture {
                showChapterSelection = true
            }
            .padding(.horizontal)
            .frame(maxWidth: .infinity)
            .background(Color.backgroundGray)
            .animation(.bouncy(duration: 0.5), value: player.currentChapter != nil)
            .sheet(isPresented: $showChapterSelection) {
                ChapterSelection()
                    .presentationDetents([.medium, .large])
                    .ignoresSafeArea(.all)
            }
        }
    }
}

#Preview {
    ChapterMiniControlView()
        .modelContainer(DataController.previewContainer)
        .environment(PlayerManager.getDummy())
}
