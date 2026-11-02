//
//  LibraryTagSection.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

struct LibraryTagSection: View {
    @Environment(\.modelContext) var modelContext
    @Environment(NavigationManager.self) var navManager

    @CloudStorage(Const.quickSwitchAllVideos) private var quickSwitchAllVideos: Bool = true

    @Query(sort: \Tag.order, animation: .default) private var tags: [Tag]

    var body: some View {
        MySection("tags", showPremiumIndicator: true, hasPadding: false) {
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
                        navManager.editedTag = .existing(tag)
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
                navManager.editedTag = .new()
            } label: {
                LibraryNavListItem("newTag", systemName: "plus")
            }
            .requiresPremium(feature: "tags")
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
            Label("quickSwitch", systemImage: Const.tagSF)
        }
    }
}

#Preview {
    List {
        LibraryTagSection()
    }
    .modelContainer(DataProvider.previewContainer)
    .environment(NavigationManager())
}
