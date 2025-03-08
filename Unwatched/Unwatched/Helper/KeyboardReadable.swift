//
//  KeyboardReadable.swift
//  Unwatched
//

import Combine

/// Publisher to read keyboard changes.
protocol KeyboardReadable { }

#if os(iOS)
import UIKit

extension KeyboardReadable {
    @MainActor
    var keyboardPublisher: AnyPublisher<Bool, Never> {
        Publishers.Merge(
            NotificationCenter.default
                .publisher(for: UIResponder.keyboardWillShowNotification)
                .map { _ in true },

            NotificationCenter.default
                .publisher(for: UIResponder.keyboardWillHideNotification)
                .map { _ in false }
        )
        .eraseToAnyPublisher()
    }
}
#endif
