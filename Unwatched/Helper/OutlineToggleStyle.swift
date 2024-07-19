//
//  CustomToggleButton.swift
//  Unwatched
//

import SwiftUI

struct OutlineToggleStyle: ToggleStyle {
    var isSmall: Bool = false
    var stroke: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        Button(action: {
            configuration.isOn.toggle()
        }, label: {
            configuration.label
                .outlineToggleModifier(isOn: configuration.isOn,
                                       isSmall: isSmall,
                                       stroke: stroke)
        })
    }
}

struct OutlineToggleModifier: ViewModifier {
    let isOn: Bool
    var isSmall: Bool = false
    var stroke: Bool = true

    func body(content: Content) -> some View {
        let size: CGFloat = isSmall ? 35 : 45
        content
            .font(.system(size: isSmall ? 15 : 18))
            .frame(width: size, height: size)
            .background(isOn ? Color.neutralAccentColor : Color.myBackgroundGray)
            .foregroundStyle(isOn ? Color.backgroundColor : Color.myForegroundGray)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(isOn || !stroke ? .clear : .myForegroundGray, lineWidth: 1)
            )
    }
}

extension View {
    func outlineToggleModifier(isOn: Bool,
                               isSmall: Bool = false,
                               stroke: Bool = true) -> some View {
        self.modifier(OutlineToggleModifier(isOn: isOn,
                                            isSmall: isSmall,
                                            stroke: stroke))
    }
}

#Preview {
    VStack {
        Toggle(isOn: .constant(true)) {
            Image(systemName: "checkmark")
        }
        .toggleStyle(OutlineToggleStyle())

        Toggle(isOn: .constant(false)) {
            Image(systemName: "checkmark")
        }
        .toggleStyle(OutlineToggleStyle(isSmall: true))
    }
}
