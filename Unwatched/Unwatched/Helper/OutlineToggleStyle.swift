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

    @Environment(\.isEnabled) var isEnabled
    @ScaledMetric var smallSize: CGFloat = 40
    @ScaledMetric var normalSize: CGFloat = 50

    init(isOn: Bool, isSmall: Bool = false, stroke: Bool = true) {
        self.isOn = isOn
        self.isSmall = isSmall
        self.stroke = stroke
    }

    func body(content: Content) -> some View {
        let size = isSmall ? smallSize : normalSize
        content
            .font(isSmall ? .subheadline : .headline)
            .fontWeight(.regular)
            .frame(width: size, height: size)
            .background(isOn ? Color.neutralAccentColor : Color.myBackgroundGray)
            .foregroundStyle(isOn ? Color.backgroundColor : Color.myForegroundGray)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .strokeBorder(isOn || !stroke ? .clear : .myForegroundGray, lineWidth: 1)
            )
            .opacity(isEnabled ? 1 : 0.4)
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
