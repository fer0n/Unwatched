//
//  DurationService.swift
//  UnwatchedShared
//

public struct HelperService {
    public static func getDurationFromChapters(_ video: VideoData) -> Double? {
        if let lastChapter = video.sortedChapterData.last {
            return lastChapter.endTime ?? lastChapter.startTime
        }
        return nil
    }
}
