//
//  CapsulePicker.swift
//  Unwatched
//

import Foundation
import SwiftUI
import UnwatchedShared

struct CapsulePicker<T: Hashable>: View {
    @Environment(\.modelContext) var modelContext

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
                    try? modelContext.save()
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
