//
//  CapsulePicker.swift
//  Unwatched
//

import Foundation
import SwiftUI

struct CapsulePicker<T: CaseIterable & Hashable>: View where T.AllCases.Element == T {
    @Binding var selection: T
    var label: (T) -> (text: String, image: String)

    var body: some View {
        Menu {
            ForEach(Array(T.allCases), id: \.self) { placement in
                Button {
                    selection = placement
                } label: {
                    let (text, image) = label(placement)
                    HStack {
                        Image(systemName: image)
                        Text(text)
                    }
                }
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
