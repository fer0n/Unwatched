import Foundation
import UnwatchedShared

extension Chapter {
    public var titleText: String? {
        title ?? category?.translated
    }

    public var titleTextForced: String {
        titleText ?? video?.title ?? mergedChapterVideo?.title ?? "-"
    }
}
