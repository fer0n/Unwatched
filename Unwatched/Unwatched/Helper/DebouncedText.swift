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
    var val = "" {
        didSet {
            handleDidSet()
        }
    }

    func handleDidSet() {
        let value = val
        let delay = self.delay
        Task { @MainActor in
            let newValue = value
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
}
