//
//  DebouncedText.swift
//  Unwatched
//

import Foundation

@Observable
class DebouncedText {
    @ObservationIgnored var task: Task<String?, Never>?
    @ObservationIgnored let delay: UInt64

    init(_ delay: Double = 0.5) {
        self.delay = UInt64(delay * 1_000_000_000)
    }

    var debounced = ""
    var val = ""

    func handleDidSet() async {
        let newValue = val
        let delay = self.delay
        task?.cancel()
        task = Task.detached {
            do {
                try await Task.sleep(nanoseconds: delay)
                return newValue
            } catch {
                return nil
            }
        }
        if let newValue = await task?.value {
            self.debounced = newValue
        }
    }
}
