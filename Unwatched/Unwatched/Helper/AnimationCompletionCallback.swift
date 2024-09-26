//
//  AnimationCompletionCallback.swift
//  Unwatched
//

import Foundation
import SwiftUI

struct AnimationCompletionCallback: AnimatableModifier {

    var targetValue: Double
    var completion: () -> Void

    init(animatedValue: Double, completion: @escaping () -> Void) {
        self.targetValue = animatedValue
        self.completion = completion
        self.animatableData = animatedValue
    }

    var animatableData: Double {
        didSet {
            checkIfFinished()
        }
    }

    func checkIfFinished() {
        if animatableData == targetValue {
            Task {
                self.completion()
            }
        }
    }

    func body(content: Content) -> some View {
        content
    }
}
