//
//  DebouncedText.swift
//  Unwatched
//

import Foundation

@Observable
class DebouncedText {
    @ObservationIgnored var task: Task<(), Never>?
    @ObservationIgnored let delay: UInt64

    init(_ delay: Double = 0.5) {
        self.delay = UInt64(delay * 1_000_000_000)
    }

    var debounced = ""
    var val = "" {
        didSet {
            let newValue = val
            task?.cancel()
            task = Task.detached {
                do {
                    try await Task.sleep(nanoseconds: self.delay)
                    await MainActor.run {
                        self.debounced = newValue
                    }
                    print("> \(newValue)")
                } catch { }
            }
        }
    }
}
