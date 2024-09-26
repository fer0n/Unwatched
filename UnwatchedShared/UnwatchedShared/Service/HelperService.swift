//
//  DurationService.swift
//  UnwatchedShared
//

public struct HelperService {
    public static func getDurationFromChapters(_ video: Video) -> Double? {
        if let lastChapter = video.sortedChapters.last {
            return lastChapter.endTime ?? lastChapter.startTime
        }
        return nil
    }
}
