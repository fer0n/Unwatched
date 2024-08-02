//
//  InnerHeightPreferenceChange.swift
//  Unwatched
//

import Foundation
import SwiftUI

struct OnSizeChangePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize { CGSize() }
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

struct OnSizeChange: ViewModifier {
    var action: (CGSize) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 18, *) {
            content
                .onGeometryChange(for: CGSize.self) { proxy in
                    proxy.size
                } action: { newValue in
                    action(newValue)
                }
        } else {
            content
                .overlay {
                    GeometryReader { geometry in
                        Color.clear.preference(key: OnSizeChangePreferenceKey.self, value: geometry.size)
                    }
                }
                .onPreferenceChange(OnSizeChangePreferenceKey.self) { newSize in
                    action(newSize)
                }
        }
    }
}

extension View {
    func onSizeChange(action: @escaping (CGSize) -> Void) -> some View {
        self.modifier(OnSizeChange(action: action))
    }
}

// geo.frame(in: .global).minY
struct OnGlobalMinYChangePreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat { .zero }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct OnGlobalMinYChange: ViewModifier {
    var action: (_ minY: CGFloat) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 18, *) {
            content
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.frame(in: .global).minY
                } action: { newValue in
                    action(newValue)
                }
        } else {
            content
                .overlay {
                    GeometryReader { geometry in
                        Color.clear.preference(key: OnGlobalMinYChangePreferenceKey.self,
                                               value: geometry.frame(in: .global).minY)
                    }
                }
                .onPreferenceChange(OnGlobalMinYChangePreferenceKey.self) { minY in
                    action(minY)
                }
        }
    }
}

extension View {
    func onGlobalMinYChange(action: @escaping (_ minY: CGFloat) -> Void) -> some View {
        self.modifier(OnGlobalMinYChange(action: action))
    }
}

struct HeightAndOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGRect { CGRect() }
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}
