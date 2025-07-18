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

    @State var viewModel = ViewModel()

    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(
                    ViewModel.formattedSpeedsEnumerated,
                    id: \.offset
                ) { index, speed in
                    Text(verbatim: speed)
                        .font(.system(size: 18))
                        .fontWidth(.compressed)
                        .fontWeight(.bold)
                        .fixedSize()
                        .id(index)
                }
                .frame(height: 10)
            }
            .scrollTargetLayout()
        }
        .opacity(viewModel.currentPage == nil ? 0 : 1)
        .onScrollInteraction { isActive in
            viewModel.handleScrolling(isActive)
            isInteracting = isActive
            if !isActive {
                viewModel.task?.cancel()
                triggerChange(viewModel.currentPage)
            }
        }
        .sensoryFeedback(Const.sensoryFeedback, trigger: viewModel.currentPage) { old, _ in
            old != nil
        }
        .scrollTargetBehavior(.viewAligned)
        .safeAreaPadding(.vertical, 20)
        .scrollPosition(id: $viewModel.currentPage, anchor: .center)
        .scrollIndicators(.never)
        .mask(viewModel.mask)
        .frame(width: 50, height: 50)
        .frame(width: viewModel.isScrolling ? nil : 22, height: viewModel.isScrolling ? nil : 22)
        .frame(width: 30, height: 30)
        .onChange(of: viewModel.currentPage) {
            guard let currentPage = viewModel.currentPage else {
                return
            }
            triggerInteraction()
            viewModel.task?.cancel()
            viewModel.task = Task {
                do {
                    try await Task.sleep(for: .milliseconds(700))
                    triggerChange(currentPage)
                } catch { }
            }
        }
        .onChange(of: value) {
            withAnimation {
                viewModel.setCurrentPage(value)
            }
        }
        .task {
            viewModel.handleAppear(value)
        }
    }

    func triggerChange(_ currentPage: Int?) {
        guard let currentPage else {
            return
        }
        let speed = ViewModel.speeds[currentPage]
        guard speed != self.value else {
            return
        }
        onChange(speed)
    }
}

extension FullscreenSpeedControlContent {
    @Observable class ViewModel {
        var isScrolling = false
        var task: Task<Void, Never>?
        var currentPage: Int?

        private var scrollingMask: LinearGradient {
            LinearGradient(gradient: Gradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.4),
                    .init(color: .black, location: 0.6),
                    .init(color: .clear, location: 1)
                ]
            ), startPoint: .top, endPoint: .bottom)
        }

        private var staticMask: LinearGradient {
            LinearGradient(gradient: Gradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .clear, location: 0.3),
                    .init(color: .black, location: 0.3),
                    .init(color: .black, location: 0.7),
                    .init(color: .clear, location: 0.7),
                    .init(color: .clear, location: 1)
                ]
            ), startPoint: .top, endPoint: .bottom)
        }

        var mask: LinearGradient {
            isScrolling ? scrollingMask : staticMask
        }

        func setCurrentPage(_ value: Double) {
            if let index = ViewModel.speeds.firstIndex(of: value),
               currentPage != index {
                currentPage = index
            }
        }

        func handleScrolling(_ isActive: Bool) {
            if isActive {
                isScrolling = isActive
            } else {
                withAnimation {
                    isScrolling = isActive
                }
            }
        }

        func handleAppear(_ value: Double) {
            setCurrentPage(value)
        }

        static let speeds: [Double] = Const.speeds.reversed()
        static let formattedSpeeds: [String] = speeds.map { speed in
            let speedText = SpeedControlViewModel.formatSpeed(speed)
            return "\(speedText)\(speedText.count <= 1 ? "×" : "")"
        }
        static let formattedSpeedsEnumerated: [(offset: Int, element: String)] = Array(formattedSpeeds.enumerated())
    }
}

extension View {
    func onScrollInteraction(_ action: @escaping (Bool) -> Void) -> some View {
        if #available(iOS 18, *) {
            return self.onScrollPhaseChange { oldPhase, newPhase in
                if oldPhase == .idle && newPhase != .idle {
                    action(true)
                } else if oldPhase != .idle && newPhase == .idle {
                    action(false)
                }
            }
        } else {
            return self
        }
    }
}
