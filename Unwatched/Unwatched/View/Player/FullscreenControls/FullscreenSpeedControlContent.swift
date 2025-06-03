//
//  FullscreenSpeedControlContent.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct FullscreenSpeedControlContent: View {
    let value: Double
    let onChange: (Double) -> Void

    let triggerInteraction: () -> Void
    @Binding var isInteracting: Bool

    @State var task: Task<Void, Never>?
    @State var currentPage: Int?

    // workaround: on macOS, when changing the window size from the left, the page
    // is often stuck in between two pages
    var animationWorkaround: Bool = false

    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(Array(Const.speeds.enumerated()), id: \.offset) { index, speed in
                    renderSpeed(speed)
                        .id(index)
                }
                .frame(height: 14)
            }
            .scrollTargetLayout()
        }
        .opacity(currentPage == nil ? 0 : 1)
        .onScrollInteraction { isActive in
            isInteracting = isActive
            if !isActive {
                task?.cancel()
                triggerChange(currentPage)
            }
        }
        .scrollTargetBehavior(.viewAligned)
        .safeAreaPadding(.vertical, 8)
        .scrollPosition(id: $currentPage, anchor: .center)
        .scrollIndicators(.never)
        .animation(.default, value: currentPage)
        .frame(width: 30, height: 30)
        .clipShape(Circle())
        .onChange(of: currentPage) {
            guard let currentPage else {
                return
            }
            triggerInteraction()
            task?.cancel()
            task = Task {
                do {
                    try await Task.sleep(for: .milliseconds(700))
                    triggerChange(currentPage)
                } catch { }
            }
        }
        .onChange(of: value, initial: !animationWorkaround) {
            setCurrentPage(value)
        }
        .task {
            if animationWorkaround {
                setCurrentPage(value)
            }
        }
        .sensoryFeedback(Const.sensoryFeedback, trigger: currentPage)
    }

    func setCurrentPage(_ value: Double) {
        if let index = Const.speeds.firstIndex(of: value),
           currentPage != index {
            currentPage = index
        }
    }

    func triggerChange(_ currentPage: Int?) {
        guard let currentPage else {
            return
        }
        let speed = Const.speeds[currentPage]
        guard speed != self.value else {
            return
        }
        onChange(speed)
    }

    func renderSpeed(_ speed: Double) -> some View {
        HStack(spacing: 0) {
            let speedText = SpeedControlViewModel.formatSpeed(speed)
            Text(verbatim: speedText)
            if speedText.count <= 1 {
                Text(verbatim: "×")
            }
        }
        .font(.system(size: 18))
        .fontWidth(.compressed)
        .fontWeight(.bold)
        .fixedSize()
    }
}

struct OnScrollInteractionModifier: ViewModifier {
    let action: (_ isActive: Bool) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 18, *) {
            content
                .onScrollPhaseChange { oldPhase, newPhase in
                    if oldPhase == .idle && newPhase != .idle {
                        action(true)
                    } else if oldPhase != .idle && newPhase == .idle {
                        action(false)
                    }
                }
        } else {
            content
        }
    }
}

extension View {
    func onScrollInteraction(_ action: @escaping (Bool) -> Void) -> some View {
        modifier(OnScrollInteractionModifier(action: action))
    }
}
