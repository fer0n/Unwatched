//
//  TrafficLights.swift
//  Unwatched
//

import SwiftUI

#if os(macOS)
@available(macOS 26, *)
private struct TrafficLightButton: View {
    let color: Color
    let symbol: String
    let action: () -> Void
    let size: CGFloat
    let showSymbol: Bool
    let isActive: Bool

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(!isActive ? .secondary : color)
                    .frame(width: size, height: size)
                if showSymbol {
                    Image(systemName: symbol)
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.black.opacity(0.5))
                        .frame(width: size * 0.6, height: size * 0.6)
                        .fontWeight(.heavy)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

@available(macOS 26, *)
struct TrafficLights: View {
    let size: CGFloat = 14
    @State private var hovering = false
    @State private var appStateObserver = AppStateObserver()

    var body: some View {
        HStack(spacing: 9) {
            TrafficLightButton(
                color: Color(red: 1, green: 0.3, blue: 0.3),
                symbol: "xmark",
                action: { NSApp.keyWindow?.performClose(nil) },
                size: size,
                showSymbol: hovering,
                isActive: appStateObserver.isActive
            )
            TrafficLightButton(
                color: Color(red: 1, green: 0.85, blue: 0.25),
                symbol: "minus",
                action: { NSApp.keyWindow?.performMiniaturize(nil) },
                size: size,
                showSymbol: hovering,
                isActive: appStateObserver.isActive
            )
            TrafficLightButton(
                color: Color(red: 0.3, green: 0.85, blue: 0.4),
                symbol: "arrow.up.left.and.arrow.down.right",
                action: { NSApp.keyWindow?.toggleFullScreen(nil) },
                size: size,
                showSymbol: hovering,
                isActive: appStateObserver.isActive
            )
        }
        .onHover { hovering = $0 }
    }
}

#Preview {
    if #available(macOS 26, *) {
        TrafficLights()
            .frame(width: 200, height: 200)
    }
}
#endif
