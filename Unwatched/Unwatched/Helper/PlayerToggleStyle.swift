//
//  CustomToggleButton.swift
//  Unwatched
//

import SwiftUI

struct PlayerToggleStyle: ToggleStyle {
    var isSmall: Bool = false
    var stroke: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        Button(action: {
            configuration.isOn.toggle()
        }, label: {
            configuration.label
                .playerToggleModifier(isOn: configuration.isOn,
                                      isSmall: isSmall,
                                      stroke: stroke)
        })
    }
}

struct PlayerToggleModifier: ViewModifier {
    let isOn: Bool
    var isSmall: Bool = false
    var stroke: Bool = true
    var backgroundColor: Color?

    @Environment(\.isEnabled) var isEnabled
    @ScaledMetric var smallSize: CGFloat = 40
    @ScaledMetric var normalSize: CGFloat = 50

    func body(content: Content) -> some View {
        content
            .symbolRenderingMode(.palette)
            #if os(macOS)
            .font(.headline)
            #else
            .font(isSmall ? .subheadline : .headline)
            #endif
            .fontWeight(.regular)
            .frame(width: size, height: size)
            .foregroundStyle(color, color.opacity(0.7))
            .opacity(isEnabled ? 1 : 0.4)
            .background(background.padding(-5))
            .clipShape(Circle())
    }

    var size: CGFloat {
        isSmall ? smallSize : normalSize
    }

    var color: Color {
        isOn ? Color.backgroundColor : Color.automaticBlack
    }

    @ViewBuilder
    var background: some View {
        if let backgroundColor {
            backgroundColor
        } else if isOn {
            Color.neutralAccentColor
        } else {
            Color.backgroundColor
        }
    }
}

extension View {
    func playerToggleModifier(isOn: Bool,
                              isSmall: Bool = false,
                              stroke: Bool = true,
                              backgroundColor: Color? = nil) -> some View {
        self.modifier(PlayerToggleModifier(isOn: isOn,
                                           isSmall: isSmall,
                                           stroke: stroke,
                                           backgroundColor: backgroundColor))
    }
}

#Preview {
    VStack {
        Toggle(isOn: .constant(true)) {
            Image(systemName: "checkmark")
        }
        .toggleStyle(PlayerToggleStyle())

        Toggle(isOn: .constant(false)) {
            Image(systemName: "checkmark")
        }
        .toggleStyle(PlayerToggleStyle(isSmall: true))
    }
}
