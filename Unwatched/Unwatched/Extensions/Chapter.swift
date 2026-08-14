import Foundation
import UnwatchedShared

extension ChapterData {
    public var titleText: String? {
        title ?? category?.translated
    }

    public func titleText(fallback videoTitle: String?) -> String {
        titleText ?? videoTitle ?? "-"
    }
}

extension Chapter {
    public var titleTextForced: String {
        titleText(fallback: video?.title ?? mergedChapterVideo?.title)
    }
}
