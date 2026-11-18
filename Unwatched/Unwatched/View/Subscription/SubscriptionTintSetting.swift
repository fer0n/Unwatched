//
//  SubscriptionTintSetting.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct SubscriptionTintSetting: View {
    @Environment(ImageCacheManager.self) var imageCacheManager
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.modelContext) var modelContext

    @Bindable var subscription: Subscription
    let imageUrl: URL

    @State private var otherColors: [Color] = []
    @State private var automaticColor: Color?

    var body: some View {
        let options = options
        return Menu {
            Picker(selection: Binding(get: { subscription.tint }, set: select)) {
                ForEach(options, id: \.tint) { option in
                    Label {
                        Text(option.name)
                    } icon: {
                        swatch(option)
                    }
                    .tag(option.tint)
                }
            } label: {
                EmptyView()
            }
            .pickerStyle(.inline)
            #if !os(macOS)
            .menuActionDismissBehavior(.disabled)
            #endif
        } label: {
            MenuItemLabel(
                title: "channelTint",
                value: subscription.tint == .automatic
                    ? nil
                    : options.first { $0.tint == subscription.tint }?.name,
                systemImage: "paintpalette"
            )
        }
        .task(id: LoadKey(imageUrl: imageUrl, colorScheme: colorScheme)) {
            await loadColors()
        }
    }

    private var resolver: PageColorResolver {
        PageColorResolver(imageCacheManager: imageCacheManager, colorScheme: colorScheme)
    }

    private var options: [TintOption] {
        var options = [
            TintOption(
                tint: .automatic,
                name: String(localized: "automaticTint"),
                color: automaticColor
            ),
            TintOption(
                tint: .monochrome,
                name: String(localized: "blackWhite"),
                color: resolver.color(for: .monochrome)
            )
        ]
        var colors = otherColors.map(PageColorChoice.init(color:))
        if case .custom = subscription.tint, !colors.contains(subscription.tint) {
            colors.append(subscription.tint)
        }
        var nameCounts = [String: Int]()
        for tint in colors {
            guard let color = tint.customColor.map(resolver.readable) else { continue }
            let name = Self.name(of: color)
            let count = (nameCounts[name] ?? 0) + 1
            nameCounts[name] = count
            options.append(TintOption(tint: tint, name: count > 1 ? "\(name) \(count)" : name, color: color))
        }
        return options
    }

    private func swatch(_ option: TintOption) -> Image {
        option.color.map(Self.colorSwatch) ?? Image(systemName: "circle.dashed")
    }

    private func select(_ choice: PageColorChoice) {
        subscription.tint = choice
        try? modelContext.save()
    }

    private func loadColors() async {
        automaticColor = resolver.cachedColor(imageUrl: imageUrl)
        let automatic = await resolver.resolve(imageUrl: imageUrl)
        let candidates = await resolver.candidates(imageUrl: imageUrl)
        guard !Task.isCancelled else { return }
        automaticColor = automatic
        otherColors = withoutAutomatic(candidates)
    }

    /// The cached automatic color can predate the current ranking, so it isn't always `candidates.first`.
    private func withoutAutomatic(_ candidates: [Color]) -> [Color] {
        let automatic = imageCacheManager[imageUrl.absoluteString]?.color.map(PageColorChoice.init(color:))
        if let index = candidates.firstIndex(where: { PageColorChoice(color: $0) == automatic }) {
            var others = candidates
            others.remove(at: index)
            return others
        }
        return Array(candidates.dropFirst())
    }

    // Menus draw SF Symbols as templates
    private static func colorSwatch(_ color: Color) -> Image {
        #if canImport(UIKit)
        let image = UIImage(systemName: "circle.fill")?
            .withTintColor(UIColor(color), renderingMode: .alwaysOriginal)
        return image.map { Image(uiImage: $0) } ?? Image(systemName: "circle.fill")
        #else
        let config = NSImage.SymbolConfiguration(paletteColors: [NSColor(color)])
        let image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        return image.map { Image(nsImage: $0) } ?? Image(systemName: "circle.fill")
        #endif
    }

    private static func name(of color: Color) -> String {
        if color.saturation < Color.graySaturation {
            return String(localized: "gray")
        }
        let key: String.LocalizationValue = switch color.hue {
        case ..<0.04: "red"
        case ..<0.11: "orange"
        case ..<0.18: "yellow"
        case ..<0.42: "green"
        case ..<0.53: "teal"
        case ..<0.72: "blue"
        case ..<0.83: "purple"
        case ..<0.95: "pink"
        default: "red"
        }
        return String(localized: key)
    }
}

private struct TintOption {
    let tint: PageColorChoice
    let name: String
    let color: Color?
}

private struct LoadKey: Equatable {
    let imageUrl: URL
    let colorScheme: ColorScheme
}
