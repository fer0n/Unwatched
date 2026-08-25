//
//  View.swift
//  Unwatched
//

import SwiftUI
import TipKit
import UnwatchedShared

extension View {
    /// Applies the given transform if the given condition evaluates to `true`.
    /// - Parameters:
    ///   - condition: The condition to evaluate.
    ///   - transform: The transform to apply to the source `View`.
    /// - Returns: Either the original `View` or the modified `View` if the condition is `true`.
    @ViewBuilder func `if`<Content: View>(
        _ condition: @autoclosure () -> Bool,
        transform: (Self) -> Content
    ) -> some View {
        if condition() {
            transform(self)
        } else {
            self
        }
    }
}

extension View {
    func apply<V: View>(@ViewBuilder _ block: (Self) -> V) -> V { block(self) }

    /// Shows the tip as an interactive popover, if there is one and `isActive`
    @ViewBuilder
    func popoverTip(_ tip: (any Tip)?, arrowEdge: Edge, isActive: Bool) -> some View {
        if let tip, isActive {
            self.popoverTip(tip, arrowEdge: arrowEdge)
                .tipBackgroundInteraction(.enabled)
        } else {
            self
        }
    }
}

extension View {
    /// Applies background color except on macOS 26
    func myListRowBackground() -> some View {
        self.listRowBackground(Const.macOS26 || Device.isVision
                                ? .clear
                                : Color.backgroundColor)
    }

    func myListInsetBackground() -> some View {
        self
            #if !os(visionOS)
            .listRowBackground(Color.insetBackgroundColor)
        #endif
    }

    /// On macOS 26, having the tabView inside the sidebar sometimes leads to the content not being clipped properly
    func concentricMacWorkaround(corners: Bool = false) -> some View {
        #if os(macOS)
        self.clipShape(RoundedRectangle(cornerRadius: corners ? 20 : 0))
        #else
        self
        #endif
    }
}

extension View {
    func previewEnvironments() -> some View {
        self
            .modelContainer(DataProvider.previewContainer)
            .environment(NavigationManager.getDummy(true))
            .environment(Alerter())
            .environment(PlayerManager.getDummy())
            .environment(ImageCacheManager())
            .environment(RefreshManager())
            .environment(SheetPositionReader.shared)
            .environment(TinyUndoManager())
            .modifier(CustomAlerter())
            #if os(macOS) || os(visionOS)
            .environment(NavigationTitleManager())
            #endif
            .appNotificationOverlay()
    }
}

/// Whether `reorderContainer` is there to do the reordering, see `View.reorderContainerIfAvailable`.
var systemReorderingAvailable: Bool {
    if #available(iOS 27, macOS 27, visionOS 27, *) {
        return true
    }
    return false
}

extension View {
    /// `reorderContainer` flattened to "put this one in front of that one", `nil` meaning the end.
    /// Nothing below iOS 27, where `reorderable(id:canReorder:dropTarget:onDrop:)` stands in for it.
    @ViewBuilder
    func reorderContainerIfAvailable<Item, ItemID: Hashable & Sendable>(
        for item: Item.Type,
        itemID: KeyPath<Item, ItemID>,
        move: @escaping (_ source: ItemID, _ before: ItemID?) -> Void
    ) -> some View {
        if #available(iOS 27, macOS 27, visionOS 27, *) {
            reorderContainer(for: item, itemID: itemID) { difference in
                guard let source = difference.sources.first else { return }
                switch difference.destination.position {
                case .before(let target):
                    move(source, target)
                case .end:
                    move(source, nil)
                }
            }
        } else {
            self
        }
    }

    /// Which item a drag is carrying, `nil` once it's over or not started. Only reports a lifted
    /// drag: hiding the row any earlier would take the drag preview's snapshot with it.
    @ViewBuilder
    func onDraggedItemChange<ItemID: Hashable>(
        of type: ItemID.Type,
        perform action: @escaping (ItemID?) -> Void
    ) -> some View {
        if #available(iOS 27, macOS 27, visionOS 27, *) {
            onDragSessionUpdated { session in
                guard case .active = session.phase else {
                    action(nil)
                    return
                }
                action(session.draggedItemIDs(for: type).first)
            }
        } else {
            self
        }
    }

    /// Drag to reorder for a `LazyVStack` below iOS 27, which has neither `onMove` nor a reorder
    /// container. An item is dragged by `id` and dropped onto the row whose place it should take.
    /// Named apart from SwiftUI's own `reorderable()` so neither shadows the other.
    @ViewBuilder
    func legacyReorderable(
        id: String,
        canReorder: Bool,
        dropTarget: Binding<String?>,
        onDrop: @escaping (String) -> Bool
    ) -> some View {
        self.if(canReorder && !systemReorderingAvailable) { view in
            view
                .draggable(id)
                .dropDestination(for: String.self) { items, _ in
                    dropTarget.wrappedValue = nil
                    guard let dropped = items.first, dropped != id else { return false }
                    return onDrop(dropped)
                } isTargeted: { isTargeted in
                    if isTargeted {
                        dropTarget.wrappedValue = id
                    } else if dropTarget.wrappedValue == id {
                        dropTarget.wrappedValue = nil
                    }
                }
        }
    }
}

extension DynamicViewContent {
    /// Marks the rows of a `reorderContainerIfAvailable` container as the ones that move.
    @ViewBuilder
    func reorderableIfAvailable() -> some View {
        if #available(iOS 27, macOS 27, visionOS 27, *) {
            reorderable()
        } else {
            self
        }
    }
}
