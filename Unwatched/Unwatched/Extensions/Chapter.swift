import Foundation
import UnwatchedShared

extension ChapterData {
    public var titleText: String? {
        title ?? category?.translated
    }

    /// Chapters without a title of their own show the video's, so pass it in — a derived
    /// chapter has no way back to its video.
    public func titleText(fallback videoTitle: String?) -> String {
        titleText ?? videoTitle ?? "-"
    }
}

extension Chapter {
    public var titleTextForced: String {
        titleText(fallback: video?.title ?? mergedChapterVideo?.title)
    }
}
