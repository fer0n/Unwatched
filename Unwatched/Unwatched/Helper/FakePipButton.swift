//
//  FakePipButton.swift
//  Unwatched
//

// FakePip window management is handled in MacOSSplitView

#if os(macOS)
import SwiftUI
import AppKit

struct FakePipTitleBar: View {
    @AppStorage("isFakePip") var isFakePip = false
    @State private var isHovered = false

    static let height: CGFloat = 35

    var body: some View {
        ZStack(alignment: .topLeading) {
            WindowDragArea()

            Button {
                isFakePip = false
            } label: {
                Image(systemName: "pip.fill")
                    .font(.system(size: 12, weight: .medium))
                    .padding(6)
                    .contentShape(Rectangle())
                    .backgroundTransparentEffect(fallback: .thinMaterial, shape: .capsule)
            }
            .buttonStyle(.plain)
            .padding([.top, .leading], 10)
            .opacity(isHovered ? 1 : 0)
            .animation(.default, value: isHovered)
        }
        .frame(height: FakePipTitleBar.height)
        .onHover { isHovered = $0 }
    }
}

/// Keeps a titlebar drag from also toggling playback in the player underneath.
struct TitlebarClickBlocker: View {
    var body: some View {
        GeometryReader { proxy in
            let height = proxy.safeAreaInsets.top
            ClickBlocker()
                .frame(height: height)
                .offset(y: -height)
        }
    }
}

private struct ClickBlocker: NSViewRepresentable {
    func makeNSView(context: Context) -> ClickBlockerNSView { ClickBlockerNSView() }
    func updateNSView(_ nsView: ClickBlockerNSView, context: Context) {}
}

private class ClickBlockerNSView: NSView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) {}
    override func mouseUp(with event: NSEvent) {}
}

struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowDragNSView { WindowDragNSView() }
    func updateNSView(_ nsView: WindowDragNSView, context: Context) {}
}

class WindowDragNSView: NSView {
    private var mouseDownEvent: NSEvent?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        mouseDownEvent = event
    }

    override func mouseDragged(with event: NSEvent) {
        guard let initial = mouseDownEvent else { return }
        mouseDownEvent = nil
        window?.performDrag(with: initial)
    }

    override func mouseUp(with event: NSEvent) {
        mouseDownEvent = nil
    }
}
#endif
