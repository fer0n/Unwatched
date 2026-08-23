//
//  NavigationTitleLabel.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

/// Its own view, so a changing `opacity` doesn't invalidate the toolbar around it
struct NavigationTitleLabel: View {
    let title: LocalizedStringKey
    let accessory: Text?
    let hidden: Bool
    let opacity: () -> Double
    /// Marks the title as a menu, the way a picker row does
    let menuIndicator: Bool

    /// Two texts that trade roles: a single `Text` with a changing `.id` leaves the outgoing copy
    /// drawing at its stale frame, over the toolbar buttons.
    @State private var slotA: LocalizedStringKey?
    @State private var slotB: LocalizedStringKey?
    @State private var showsB = false

    init(
        title: LocalizedStringKey,
        accessory: Text? = nil,
        hidden: Bool = false,
        opacity: @escaping () -> Double = { 1 },
        menuIndicator: Bool = false
    ) {
        self.title = title
        self.accessory = accessory
        self.hidden = hidden
        self.opacity = opacity
        self.menuIndicator = menuIndicator
        _slotA = State(initialValue: title)
    }

    var body: some View {
        ZStack {
            titleLabel(slotA, isFront: !showsB)
            titleLabel(slotB, isFront: showsB)
        }
        .offset(y: hidden ? 10 : 0)
        .opacity(hidden ? 0 : opacity())
        .blur(radius: hidden ? 3 : 0)
        .lineLimit(1)
        .onChange(of: title) {
            // not `contentTransition`: it crossfades glyph by glyph, blending two titles into a
            // word that is neither
            if showsB {
                slotA = title
            } else {
                slotB = title
            }
            withAnimation(.smooth(duration: 0.25)) {
                showsB.toggle()
            }
        }
        .task(id: showsB) {
            // drop the faded-out title afterwards, nothing needs it anymore
            try? await Task.sleep(for: .seconds(0.4))
            guard !Task.isCancelled else { return }
            if showsB {
                slotA = nil
            } else {
                slotB = nil
            }
        }
    }

    /// Always present, so the incoming copy has an opacity to animate *from*. What trails the
    /// title belongs to the copy, so it fades along with it instead of sliding to the new width.
    private func titleLabel(_ key: LocalizedStringKey?, isFront: Bool) -> some View {
        HStack(spacing: 0) {
            Text(key ?? "")
                .fontWeight(.black)
            trailingLabels
        }
        .opacity(isFront ? 1 : 0)
        .blur(radius: isFront ? 0 : 5)
        .scaleEffect(isFront ? 1 : 0.92)
    }

    /// Zero width, so what hangs off the title doesn't push it out of the center
    @ViewBuilder private var trailingLabels: some View {
        HStack(spacing: 5) {
            if let accessory {
                accessory
                    .contentTransition(.numericText())
            }
            if menuIndicator {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
            }
        }
        .fixedSize()
        .frame(width: 0, alignment: .leading)
        .offset(x: 4)
    }
}
