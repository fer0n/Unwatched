//
//  InnerHeightPreferenceChange.swift
//  Unwatched
//

import Foundation
import SwiftUI

struct InnerSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize { CGSize() }
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

struct InnerSizeTrackerModifier: ViewModifier {
    var onChange: (CGSize) -> Void

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geometry in
                    Color.clear.preference(key: InnerSizePreferenceKey.self, value: geometry.size)
                }
            }
            .onPreferenceChange(InnerSizePreferenceKey.self) { newSize in
                onChange(newSize)
            }
    }
}

extension View {
    func innerSizeTrackerModifier(onChange: @escaping (CGSize) -> Void) -> some View {
        self.modifier(InnerSizeTrackerModifier(onChange: onChange))
    }
}

// geo.frame(in: .global).minY
struct GlobalMinYPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat { .zero }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct GlobalMinYTrackerModifier: ViewModifier {
    var onChange: (_ minY: CGFloat) -> Void

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geometry in
                    Color.clear.preference(key: GlobalMinYPreferenceKey.self, value: geometry.frame(in: .global).minY)
                }
            }
            .onPreferenceChange(GlobalMinYPreferenceKey.self) { minY in
                onChange(minY)
            }
    }
}

extension View {
    func globalMinYTrackerModifier(onChange: @escaping (_ minY: CGFloat) -> Void) -> some View {
        self.modifier(GlobalMinYTrackerModifier(onChange: onChange))
    }
}

struct HeightAndOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGRect { CGRect() }
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}
