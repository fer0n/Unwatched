//
//  CapsulePicker.swift
//  Unwatched
//

import Foundation
import SwiftUI
import UnwatchedShared

struct CapsulePicker<T: Hashable>: View {
    @Binding var selection: T
    var options: [T]
    var label: (T) -> (text: String, image: String)
    var menuLabel: LocalizedStringKey

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button {
                    withAnimation {
                        selection = option
                    }
                } label: {
                    let (text, image) = label(option)
                    Label(text, systemImage: image)
                }
                .disabled(selection == option)
            }
        } label: {
            let (text, image) = label(selection)
            CapsuleMenuLabel(systemImage: image,
                             menuLabel: menuLabel,
                             text: text)
        }
        .buttonStyle(CapsuleButtonStyle(primary: false))
    }
}

struct CapsuleMenuLabel: View {
    var systemImage: String
    var menuLabel: LocalizedStringKey
    var text: String

    var body: some View {
        VStack(alignment: .leading) {
            Label(menuLabel, systemImage: systemImage)
                .font(.system(size: 13))
                .opacity(0.7)
            Text(text)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
    }
}

#Preview {
    CapsulePicker(
        selection: .constant(VideoPlacement.defaultPlacement),
        options: VideoPlacement.allCases,
        label: {
            let text = $0.description(defaultPlacement: VideoPlacement.inbox.shortDescription)
            let img = $0.systemName
                ?? VideoPlacement.inbox.systemName
                ?? "questionmark"
            return (text, img)
        },
        menuLabel: "videoPlacement")
}
