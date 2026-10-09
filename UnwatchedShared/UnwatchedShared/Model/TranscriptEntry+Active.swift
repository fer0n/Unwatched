//
//  TranscriptEntry+Active.swift
//  UnwatchedShared
//

public extension Array where Element == TranscriptEntry {
    func activeIndex(at time: Double, gaps: [TranscriptAlignment.Gap] = []) -> Int? {
        guard let index = lastIndex(startedBy: time) else { return nil }
        let isInUncoveredGap = gaps.contains { $0.contains(time) && self[index].start < $0.audioStart }
        return isInUncoveredGap ? nil : index
    }

    private func lastIndex(startedBy time: Double) -> Int? {
        var low = 0
        var high = count
        while low < high {
            let mid = (low + high) / 2
            if self[mid].start <= time {
                low = mid + 1
            } else {
                high = mid
            }
        }
        return low > 0 ? low - 1 : nil
    }
}

extension TranscriptAlignment.Gap {
    func contains(_ time: Double) -> Bool {
        audioStart <= time && time < audioEnd
    }
}
