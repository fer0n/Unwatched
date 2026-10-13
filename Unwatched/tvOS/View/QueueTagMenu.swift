//
//  QueueTagMenu.swift
//  UnwatchedTV
//

import SwiftUI
import UnwatchedShared

struct QueueTagMenu: View {
    let tags: [Tag]
    @Binding var selection: Tag?

    var body: some View {
        Menu {
            Picker(selection: $selection) {
                Label("allVideos", systemImage: "list.bullet")
                    .tag(Tag?.none)
                ForEach(tags) { tag in
                    Label(tag.name, systemImage: tag.displaySymbol)
                        .tag(Optional(tag))
                }
            } label: {
                EmptyView()
            }
            .pickerStyle(.inline)
        } label: {
            if let selection {
                Label(selection.name, systemImage: selection.displaySymbol)
            } else {
                Label("tags", systemImage: Const.tagSF)
            }
        }
    }
}
