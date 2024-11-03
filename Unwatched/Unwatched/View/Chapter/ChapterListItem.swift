import SwiftUI
import UnwatchedShared

struct ChapterListItem: View {
    var chapter: Chapter
    var toggleChapter: (_ chapter: Chapter) -> Void
    var timeText: String

    @ScaledMetric var frameSize = 30
    @State var toggleHaptic = false

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
                    .animation(.default, value: timeText)
                    .contentTransition(.numericText(countsDown: true))
                    .foregroundStyle(Color.gray)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(nil, value: chapter.isActive)
            .opacity(chapter.isActive ? 1 : 0.6)
        }
    }

    var toggleChapterButton: some View {
        Button {
            toggleChapter(chapter)
            toggleHaptic.toggle()
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
            .animation(nil, value: chapter.isActive)
        }
        .accessibilityLabel(chapter.isActive ? "chapterOn" : "chapterOff")
        .sensoryFeedback(Const.sensoryFeedback, trigger: toggleHaptic)
    }
}

#Preview {
    VStack {
        ChapterListItem(chapter: Chapter(
            title: "Hello there",
            time: 102
        ), toggleChapter: { _ in true },
        timeText: "0 remaining")
        .background(Color.gray)

        ChapterListItem(chapter: Chapter(
            title: nil,
            time: 102
        ), toggleChapter: { _ in true },
        timeText: "0 remaining")
        .background(Color.gray)
    }
}
