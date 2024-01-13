//
//  CustomToggleButton.swift
//  Unwatched
//

import SwiftUI

struct OutlineToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: {
            configuration.isOn.toggle()
        }, label: {
            configuration.label
                .modifier(OutlineToggleModifier(isOn: configuration.isOn))
        })
    }
}

struct OutlineToggleModifier: ViewModifier {
    let isOn: Bool

    func body(content: Content) -> some View {
        content
            .font(.system(size: 14))
            .padding(.vertical, 15)
            .padding(.horizontal, 15)
            .frame(maxWidth: 110)
            .background(isOn ? Color.myAccentColor : Color.myBackgroundGray)
            .foregroundColor(isOn ? Color.backgroundColor : Color.myForegroundGray)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isOn ? Color.clear : Color.myForegroundGray, lineWidth: 2)
            )
    }
}

#Preview {
    Toggle(isOn: .constant(true)) {
        Text("Custom\nsettings")
    }
    .toggleStyle(OutlineToggleStyle())
}
