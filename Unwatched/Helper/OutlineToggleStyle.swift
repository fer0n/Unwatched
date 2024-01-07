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
                .padding(.vertical, 10)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .background(configuration.isOn ? Color.accentColor : Color.myBackgroundGray)
                .foregroundColor(configuration.isOn ? Color.backgroundColor : Color.myForegroundGray)
                .clipShape(RoundedRectangle(cornerRadius: 50))
                .overlay(
                    RoundedRectangle(cornerRadius: 50)
                        .stroke(configuration.isOn ? Color.clear : Color.myForegroundGray, lineWidth: 2)
                )
        })
    }
}

#Preview {
    Toggle(isOn: .constant(true)) {
        Text("Custom settings for this feed")
    }
    .toggleStyle(OutlineToggleStyle())
}
