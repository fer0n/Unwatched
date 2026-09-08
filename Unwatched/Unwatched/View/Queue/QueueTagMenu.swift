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
        if tags.isEmpty {
            label(nil)
        } else {
            Group {
                if hasQuickSwitch {
                    Menu {
                        picker
                    } label: {
                        label(symbol)
                    } primaryAction: {
                        switchBy(1)
                    }
                } else {
                    Menu {
                        picker
                    } label: {
                        label(symbol)
                    }
                }
            }
            .menuIndicator(.hidden)
            .quickSwitchSwipe(switchBy: switchBy)
            .sensoryFeedback(Const.sensoryFeedback, trigger: navManager.queueTag)
        }
    }

    private var picker: some View {
        @Bindable var navManager = navManager

        return Picker("filterByTag", selection: $navManager.queueTag.animation(.snappy)) {
            Label("allVideos", systemImage: Const.allVideosViewSF)
                .tag(QueueTagSelection.all)
            ForEach(tags) { tag in
                Label(tag.name, systemImage: tag.displaySymbol)
                    .tag(QueueTagSelection.tag(tag.persistentModelID))
            }
        }
        .pickerStyle(.inline)
    }

    private var symbol: String {
        switch navManager.queueTag {
        case .all: Const.filterTagSF
        case .tag: navManager.queueTag.tag(in: tags)?.displaySymbol ?? Const.filterTagSF
        }
    }

    private var quickSwitchSelections: [QueueTagSelection] {
        (quickSwitchAllVideos ? [QueueTagSelection.all] : [])
            + tags.filter(\.quickSwitch).map { .tag($0.persistentModelID) }
    }

    /// A rotation of one would leave the tap doing nothing, so the menu takes the tap instead
    private var hasQuickSwitch: Bool {
        quickSwitchSelections.count > 1
    }

    private var switchSelections: [QueueTagSelection] {
        hasQuickSwitch
            ? quickSwitchSelections
            : [.all] + tags.map { .tag($0.persistentModelID) }
    }

    private func switchBy(_ offset: Int) {
        let selections = switchSelections
        guard !selections.isEmpty else { return }

        let next: QueueTagSelection
        if let index = selections.firstIndex(of: navManager.queueTag) {
            next = selections[(index + offset + selections.count) % selections.count]
        } else {
            next = offset > 0 ? selections[0] : selections[selections.count - 1]
        }
        guard next != navManager.queueTag else { return }

        withAnimation {
            navManager.queueTag = next
        }
    }
}

private extension View {
    func quickSwitchSwipe(switchBy: @escaping (Int) -> Void) -> some View {
        #if os(iOS)
        gesture(QuickSwitchSwipe(switchBy: switchBy))
        #else
        self
        #endif
    }
}

#if os(iOS)

/// A UIKit pan rather than a `DragGesture`: that one loses to the menu's own recognizers,
/// this one runs alongside them and still leaves the tap to open the menu
private struct QuickSwitchSwipe: UIGestureRecognizerRepresentable {
    let switchBy: (Int) -> Void

    private static let minDistance: CGFloat = 24
    private static let minFlickVelocity: CGFloat = 300

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let recognizer = UIPanGestureRecognizer()
        recognizer.delegate = context.coordinator
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        let coordinator = context.coordinator

        switch recognizer.state {
        case .began:
            coordinator.didSwitch = false
        case .changed, .ended:
            guard !coordinator.didSwitch, let offset = switchOffset(recognizer) else { return }
            coordinator.didSwitch = true
            switchBy(offset)
        default:
            break
        }
    }

    /// A flick too short to pass the distance still counts, its speed is only known at the end
    private func switchOffset(_ recognizer: UIPanGestureRecognizer) -> Int? {
        let translation = recognizer.translation(in: nil)
        guard abs(translation.x) > abs(translation.y) else { return nil }

        let isFlick = recognizer.state == .ended
            && abs(recognizer.velocity(in: nil).x) > Self.minFlickVelocity
        guard abs(translation.x) > Self.minDistance || isFlick else { return nil }

        return translation.x < 0 ? 1 : -1
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var didSwitch = false

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}
#endif

/// The queue title doubles as the tag switcher: a tap steps through the quick switch rotation
/// or opens the menu, swiping always steps through
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
