//
//  QueueTagMenu.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

/// - Parameter label: gets the selected slice's symbol, or nil when there are no tags to
///   switch between and the menu stays away
struct QueueTagMenu<MenuLabel: View>: View {
    @Environment(NavigationManager.self) private var navManager

    @CloudStorage(Const.quickSwitchAllVideos) private var quickSwitchAllVideos: Bool = true

    @Query(sort: \Tag.order) private var tags: [Tag]

    @ViewBuilder var label: (String?) -> MenuLabel

    var body: some View {
        @Bindable var navManager = navManager

        if tags.isEmpty {
            label(nil)
        } else {
            Menu {
                Picker("filterByTag", selection: $navManager.queueTag.animation(.snappy)) {
                    Label("allVideos", systemImage: Const.allVideosViewSF)
                        .tag(QueueTagSelection.all)
                    ForEach(tags) { tag in
                        Label(tag.name, systemImage: tag.displaySymbol)
                            .tag(QueueTagSelection.tag(tag.persistentModelID))
                    }
                }
                .pickerStyle(.inline)
            } label: {
                label(symbol)
            } primaryAction: {
                withAnimation {
                    navManager.queueTag = nextSelection
                }
            }
            .menuIndicator(.hidden)
            .sensoryFeedback(Const.sensoryFeedback, trigger: navManager.queueTag)
        }
    }

    private var symbol: String {
        switch navManager.queueTag {
        case .all: Const.filterTagSF
        case .tag: navManager.queueTag.tag(in: tags)?.displaySymbol ?? Const.filterTagSF
        }
    }

    private var allSelections: [QueueTagSelection] {
        [.all] + tags.map { .tag($0.persistentModelID) }
    }

    /// Quick switch off everywhere would leave the button doing nothing, so it falls back to all.
    private var quickSwitchSelections: [QueueTagSelection] {
        let selections = (quickSwitchAllVideos ? [QueueTagSelection.all] : [])
            + tags.filter(\.quickSwitch).map { .tag($0.persistentModelID) }
        return selections.isEmpty ? allSelections : selections
    }

    /// Wraps, so the button alone reaches every slice in the rotation.
    private var nextSelection: QueueTagSelection {
        let selections = quickSwitchSelections
        guard let index = selections.firstIndex(of: navManager.queueTag) else {
            return selections.first ?? .all
        }
        return index + 1 < selections.count ? selections[index + 1] : selections[0]
    }
}

/// The queue title doubles as the tag switcher: tapping cycles the slices, holding opens the menu.
struct QueueTagTitle: View {
    let title: LocalizedStringKey

    var body: some View {
        QueueTagMenu { symbol in
            NavigationTitleLabel(title: title, menuIndicator: symbol != nil)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                // the title's blur layers otherwise swallow the tap
                .contentShape(.rect)
        }
        .foregroundStyle(Color.neutralAccentColor)
    }
}
