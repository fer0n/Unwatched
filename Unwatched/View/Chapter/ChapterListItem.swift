import SwiftUI

struct ChapterListItem: View {
    var chapter: Chapter
    var toggleChapter: (_ chapter: Chapter) -> Void
    var timeText: String
    var jumpDisabled: Bool = false

    @ScaledMetric var frameSize = 30

    var body: some View {
        HStack {
            toggleChapterButton
                .opacity(chapter.isActive ? 1 : 0.6)

            VStack(alignment: .leading) {
                if let title = chapter.titleText {
                    Text(title)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Text(timeText)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Color.gray)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(chapter.isActive && !jumpDisabled ? 1 : 0.6)
        }
    }

    var toggleChapterButton: some View {
        Button {
            toggleChapter(chapter)
        } label: {
            ZStack {
                Image(systemName: Const.circleBackgroundSF)
                    .resizable()
                    .frame(width: frameSize, height: frameSize)
                    .foregroundStyle(Color.backgroundColor)
                if chapter.isActive {
                    Image(systemName: Const.checkmarkSF)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.neutralAccentColor)
                }
            }
            .animation(nil, value: UUID())
        }
        .accessibilityLabel(chapter.isActive ? "chapterOn" : "chapterOff")
    }
}

#Preview {
    VStack {
        ChapterListItem(chapter: Chapter(
            title: "Hello there",
            time: 102
        ), toggleChapter: { _ in },
        timeText: "0 remaining")
        .background(Color.gray)

        ChapterListItem(chapter: Chapter(
            title: nil,
            time: 102
        ), toggleChapter: { _ in },
        timeText: "0 remaining")
        .background(Color.gray)
    }
}
