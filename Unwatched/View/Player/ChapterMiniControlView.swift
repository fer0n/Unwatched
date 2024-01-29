//
//  ChapterMiniControlView.swift
//  Unwatched
//

import SwiftUI

struct ChapterMiniControlView: View {
    @Environment(PlayerManager.self) var player
    @Environment(NavigationManager.self) var navManager

    var body: some View {
        let hasChapters = player.currentChapter != nil
        let hasDesc = player.video?.videoDescription != nil

        if hasChapters || hasDesc {
            VStack(spacing: 10) {
                if let chapter = player.currentChapter {
                    chapterMiniController(chapter)
                }
                if hasChapters && hasDesc {
                    Divider()
                }
                if let description = player.video?.videoDescription {
                    videoDescription(description, hasChapters)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color.backgroundGray)
            .animation(.bouncy(duration: 0.5), value: player.currentChapter != nil)
        }
    }

    func videoDescription(_ description: String, _ hasChapters: Bool) -> some View {
        Button {
            navManager.selectedDetailPage = .description
            navManager.showDescriptionDetail = true
        } label: {
            Text(description)
                .foregroundStyle(Color.foregroundGray)
                .font(.system(size: 14))
                .lineLimit(hasChapters ? 1 : 2)
        }
    }

    func chapterMiniController(_ chapter: Chapter) -> some View {
        HStack {
            Button(action: player.goToPreviousChapter) {
                Image(systemName: "backward.end.fill")
            }
            .disabled(player.previousChapter == nil)
            Button {
                navManager.selectedDetailPage = .chapters
                navManager.showDescriptionDetail = true
            } label: {
                VStack(spacing: 2) {
                    Text(chapter.title)
                        .fontWeight(.bold)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                    if let remaining = player.currentRemaining {
                        Text(remaining)
                            .foregroundStyle(Color.foregroundGray)
                            .font(.system(size: 14))
                            .lineLimit(1)
                    }
                }
            }

            Button(action: player.goToNextChapter) {
                Image(systemName: "forward.end.fill")
            }
            .disabled(player.nextChapter == nil)
        }
    }
}

#Preview {
    ChapterMiniControlView()
        .modelContainer(DataController.previewContainer)
        .environment(PlayerManager.getDummy())
}
