//
//  CapsulePicker.swift
//  Unwatched
//

import Foundation
import SwiftUI
import UnwatchedShared
import SwiftData

struct CapsulePicker<T: Hashable>: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.settingControlStyle) var style
    @Environment(\.premiumLockedFeature) var premiumLockedFeature

    @Binding var selection: T
    var options: [T]
    var label: (T) -> (text: String, image: String?)
    var menuLabel: LocalizedStringKey
    var fallbackSystemImage = "questionmark"
    var compactText: ((T) -> String)?
    var compactIconText: String?
    var hidesMenuValue = false
    var menuStep: ((T, Int) -> T?)?

    @Environment(\.compactSettingValues) private var compact

    var body: some View {
        if style == .menuItem {
            menuPicker
        } else {
            capsuleMenu
        }
    }

    var menuPicker: some View {
        let guarded = Binding(
            get: { selection },
            set: { value in
                if let premiumLockedFeature, !guardPremium(premiumLockedFeature) {
                    return
                }
                selection = value
                try? modelContext.save()
            }
        )
        let (text, image) = label(selection)
        return Menu {
            if let menuStep {
                menuStepper(selection: guarded, step: menuStep)
            }
            Picker(selection: guarded) {
                ForEach(options, id: \.self) { option in
                    Text(label(option).text)
                        .tag(option)
                }
            } label: {
                EmptyView()
            }
            .pickerStyle(.inline)
        } label: {
            MenuItemLabel(
                title: menuLabel,
                value: hidesMenuValue ? nil : text,
                systemImage: image ?? fallbackSystemImage
            )
        }
    }

    private func menuStepper(selection: Binding<T>, step: @escaping (T, Int) -> T?) -> some View {
        MenuValueStepper(
            value: label(selection.wrappedValue).text,
            decrementLabel: "decreaseSpeed",
            incrementLabel: "increaseSpeed",
            onDecrement: stepAction(by: -1, selection: selection, step: step),
            onIncrement: stepAction(by: 1, selection: selection, step: step)
        )
        #if !os(macOS)
        .menuActionDismissBehavior(premiumLockedFeature == nil && !hidesPremiumEntries ? .disabled : .automatic)
        #endif
    }

    private func stepAction(
        by delta: Int,
        selection: Binding<T>,
        step: @escaping (T, Int) -> T?
    ) -> (() -> Void)? {
        guard step(selection.wrappedValue, delta) != nil else { return nil }
        return {
            if let next = step(selection.wrappedValue, delta) {
                selection.wrappedValue = next
            }
        }
    }

    var capsuleMenu: some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button {
                    withAnimation {
                        selection = option
                    }
                    try? modelContext.save()
                } label: {
                    let (text, image) = label(option)
                    if let image {
                        Label(text, systemImage: image)
                    } else {
                        Text(text)
                    }
                }
                .disabled(selection == option)
            }
        } label: {
            let (text, image) = label(selection)
            CapsuleMenuLabel(systemImage: image ?? fallbackSystemImage,
                             menuLabel: menuLabel,
                             text: compact ? (compactText?(selection) ?? text) : text,
                             iconText: compactIconText)
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
