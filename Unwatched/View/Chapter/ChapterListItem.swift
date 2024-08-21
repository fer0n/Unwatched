import SwiftUI

struct ChapterListItem: View {
    var chapter: Chapter
    var toggleChapter: (_ chapter: Chapter) -> Void
    var timeText: String

    var body: some View {
        HStack {
            toggleChapterButton

            VStack(alignment: .leading) {
                if let title = chapter.titleText {
                    Text(title)
                        .lineLimit(1)
                }
                Text(timeText)
                    .animation(.default, value: timeText)
                    .contentTransition(.numericText(countsDown: true))
                    .font(.system(size: 14).monospacedDigit())
                    .foregroundStyle(Color.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    var toggleChapterButton: some View {
        Button {
            toggleChapter(chapter)
        } label: {
            ZStack {
                Image(systemName: Const.circleBackgroundSF)
                    .resizable()
                    .frame(width: 30, height: 30)
                    .foregroundStyle(Color.backgroundColor)
                if chapter.isActive {
                    Image(systemName: Const.checkmarkSF)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.neutralAccentColor)
                }
            }
            .animation(nil, value: UUID())
        }
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
