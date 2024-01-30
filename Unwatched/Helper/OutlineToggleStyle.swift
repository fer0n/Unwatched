//
//  CustomToggleButton.swift
//  Unwatched
//

import SwiftUI

struct OutlineToggleStyle: ToggleStyle {
    var isSmall: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        Button(action: {
            configuration.isOn.toggle()
        }, label: {
            configuration.label
                .modifier(OutlineToggleModifier(isOn: configuration.isOn, isSmall: isSmall))
        })
    }
}

struct OutlineToggleModifier: ViewModifier {
    let isOn: Bool
    var isSmall: Bool = false

    func body(content: Content) -> some View {
        content
            .font(.system(size: isSmall ? 15 : 18))
            .padding(isSmall ? 10 : 15)
            .background(isOn ? Color.myAccentColor : Color.myBackgroundGray)
            .foregroundColor(isOn ? Color.backgroundColor : Color.myForegroundGray)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(isOn ? Color.clear : Color.myForegroundGray, lineWidth: 1)
            )
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
