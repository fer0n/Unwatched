//
//  LibraryTagSection.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

struct LibraryTagSection: View {
    @Environment(\.modelContext) var modelContext

    @CloudStorage(Const.quickSwitchAllVideos) private var quickSwitchAllVideos: Bool = true

    @Query(sort: \Tag.order, animation: .default) private var tags: [Tag]

    @Binding var editedTag: TagEdit?

    var body: some View {
        MySection("tags", hasPadding: false) {
            NavigationLink(value: LibraryDestination.allVideos) {
                LibraryNavListItem("allVideos", systemName: Const.allVideosViewSF)
            }
            .contextMenu {
                QuickSwitchToggle(isOn: $quickSwitchAllVideos)
            }

            ForEach(tags) { tag in
                NavigationLink(value: LibraryDestination.tag(tag.name)) {
                    LibraryNavListItem(.verbatim(tag.name), systemName: tag.displaySymbol)
                }
                .contextMenu {
                    Button {
                        editedTag = .existing(tag)
                    } label: {
                        Label("editTag", systemImage: Const.settingsViewSF)
                    }
                    QuickSwitchToggle(isOn: Binding(
                        get: { tag.quickSwitch },
                        set: { tag.quickSwitch = $0; save() }
                    ))
                }
            }
            .onDelete(perform: delete)
            .onMove(perform: move)

            Button {
                editedTag = .new()
            } label: {
                LibraryNavListItem("newTag", systemName: "plus")
            }
        }
    }

    private func save() {
        try? modelContext.save()
    }

    private func delete(at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(tags[index])
            }
        }
        save()
    }

    private func move(from source: IndexSet, to destination: Int) {
        var reordered = tags
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, tag) in reordered.enumerated() where tag.order != index {
            tag.order = index
        }
        save()
    }
}

struct QuickSwitchToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Label("quickSwitch", systemImage: Const.filterTagSF)
        }
    }
}

#Preview {
    @Previewable @State var editedTag: TagEdit?
    List {
        LibraryTagSection(editedTag: $editedTag)
    }
    .modelContainer(DataProvider.previewContainer)
}
