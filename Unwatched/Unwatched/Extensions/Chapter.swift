import Foundation
import UnwatchedShared

extension ChapterData {
    public var titleText: String? {
        guard let category else {
            return title
        }
        switch category {
        case .sponsor, .selfpromo:
            guard let title, !title.isEmpty else {
                return category.translated
            }
            guard let prefix = category.translated else {
                return title
            }
            return "\(prefix) \(title)"
        default:
            return title ?? category.translated
        }
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
