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
                Button(action: player.goToPreviousChapter) {
                    Image(systemName: "backward.end.fill")
                }
                .disabled(player.previousChapter == nil)
                Button {
                    showChapterSelection = true
                } label: {
                    Text(chapter.title)
                        .fontWeight(.bold)
                        .lineLimit(1)
                        .padding()
                        .frame(maxWidth: .infinity)
                }

                Button(action: player.goToNextChapter) {
                    Image(systemName: "forward.end.fill")
                }
                .disabled(player.nextChapter == nil)
            }
            .padding(.horizontal)
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
