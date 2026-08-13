//
//  QueueOrder.swift
//  UnwatchedShared
//

import Foundation

/// Arithmetic for `QueueEntry.order`, kept free of SwiftData so it can be tested directly.
///
/// `order` is a sort key with gaps, not a position: an entry goes in between its neighbours'
/// values and the rest of the queue is left alone. Values are arbitrary `Int`s — negative for
/// entries added to the top — and only their relative order carries meaning, so nothing may read
/// one as an index or compare it against `0` to recognise the top of the queue.
///
/// Dense `0..<n` ordering meant every insertion, move and deletion rewrote every entry below it,
/// and with iCloud sync on each rewritten row is a CKRecord update.
public enum QueueOrder {
    /// Wide enough that repeatedly inserting into the same gap — queueing several videos as "next"
    /// in a row halves it each time — takes 20 insertions before it runs out and the queue has to
    /// be renumbered. `Int` has room to spare: a million entries this far apart is still a
    /// thousandth of `Int.max`.
    public static let step = 1 << 20

    /// Orders for `count` entries placed at `position` among `existing` (ascending). `position` is
    /// an index into the queue as it looks *without* the entries being placed, clamped into
    /// `0...existing.count` — so it goes to the top below `0` and to the bottom above the count.
    /// Callers using `insertQueueEntries`' `-1` sentinel for "append" must convert it first.
    ///
    /// `nil` when the neighbours are too close together to fit the new entries between them —
    /// callers fall back to `renumbered(count:)` for the whole queue.
    public static func insert(count: Int, at position: Int, into existing: [Int]) -> [Int]? {
        guard count > 0 else { return [] }
        guard let first = existing.first, let last = existing.last else {
            return renumbered(count: count)
        }

        // `QueueEntry.order` defaults to `Int.max`, and a merge can leave any value behind, so
        // stepping past an existing order can overflow. Renumbering resolves it.
        if position <= 0 {
            let (lowest, overflow) = first.subtractingReportingOverflow(count * step)
            guard !overflow else { return nil }
            return (0..<count).map { lowest + $0 * step }
        }
        guard position < existing.count else {
            let (highest, overflow) = last.addingReportingOverflow(count * step)
            guard !overflow else { return nil }
            return (1...count).map { highest - (count - $0) * step }
        }

        let lower = existing[position - 1]
        let upper = existing[position]
        let (gap, overflow) = upper.subtractingReportingOverflow(lower)
        guard !overflow else { return nil }
        let increment = gap / (count + 1)
        guard increment >= 1 else { return nil }
        return (1...count).map { lower + $0 * increment }
    }

    /// Evenly spaced orders for a whole queue of `count` entries.
    public static func renumbered(count: Int) -> [Int] {
        (0..<count).map { $0 * step }
    }

    /// Whether `orders` (ascending) are still strictly increasing, i.e. describe an unambiguous
    /// queue. Sync merges can leave two entries sharing a value; `renumbered(count:)` repairs it.
    public static func isValid(_ orders: [Int]) -> Bool {
        zip(orders, orders.dropFirst()).allSatisfy { $0 < $1 }
    }
}
