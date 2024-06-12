//
//  CapsulePicker.swift
//  Unwatched
//

import Foundation
import SwiftUI

struct CapsulePicker<T: Hashable>: View {
    @Binding var selection: T
    var options: [T]
    var label: (T) -> (text: String, image: String)

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button {
                    withAnimation {
                        selection = option
                    }
                } label: {
                    let (text, image) = label(option)
                    HStack {
                        Image(systemName: image)
                        Text(text)
                    }
                }
                .disabled(selection == option)
            }
        } label: {
            let (text, image) = label(selection)
            HStack {
                Image(systemName: image)
                Text(text)
            }
            .padding(10)
        }
        .buttonStyle(CapsuleButtonStyle())
    }
}
