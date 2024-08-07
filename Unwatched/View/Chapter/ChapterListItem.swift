import SwiftUI

struct ChapterListItem: View {
    var chapter: Chapter
    var toggleChapter: (_ chapter: Chapter) -> Void
    var timeText: String

    var body: some View {
        HStack {
            toggleChapterButton

            VStack(alignment: .leading) {
                Text(chapter.title)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(timeText)
                    .animation(.default, value: timeText)
                    .contentTransition(.numericText(countsDown: true))
                    .font(.system(size: 14).monospacedDigit())
                    .foregroundStyle(Color.gray)
            }
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
    HStack {
        ChapterListItem(chapter: Chapter(
            title: "Hello there",
            time: 102
        ), toggleChapter: { _ in },
        timeText: "0 remaining")
        .background(Color.gray)
    }
    .fixedSize()
}
