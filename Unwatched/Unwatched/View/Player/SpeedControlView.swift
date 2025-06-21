//
//  PlaybackSpeedControl.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct SpeedControlView: View {
    @State var viewModel = SpeedControlViewModel()

    @Binding var selectedSpeed: Double
    @ScaledMetric var thumbSize: CGFloat = 35

    let frameHeight: CGFloat = 35
    let coordinateSpace: NamedCoordinateSpace = .named("speed")
    let borderWidth: CGFloat = 2
    var indicatorSpacing: CGFloat = 2

    var body: some View {
        ZStack {
            Spacer()
                .frame(height: frameHeight)
                .frame(maxWidth: .infinity)

            SpeedSliderBackground(
                onTap: onSpeedTap,
                showDecimalHighlights: viewModel.showDecimalHighlights,
                thumbSize: thumbSize,
                indicatorSpacing: indicatorSpacing
            )
            .padding(.horizontal, viewModel.padding)
            .overlay {
                GeometryReader { geometry in
                    Color.clear.preference(key: SpeedPreferenceKey.self, value: geometry.frame(in: coordinateSpace))
                }
            }
            .onPreferenceChange(SpeedPreferenceKey.self) { minY in
                if minY.width == viewModel.width {
                    return
                }
                Task { @MainActor in
                    viewModel.width = minY.width
                    viewModel.itemWidth = (minY.width - thumbSize) / CGFloat(Const.speeds.count - 1)
                    viewModel.padding = thumbSize / 2 - viewModel.itemWidth / 2
                    viewModel.setThumbPosition(to: selectedSpeed)
                    if !viewModel.showContent {
                        viewModel.showContent = true
                    }
                }
            }

            SpeedSliderThumb(
                viewModel: $viewModel,
                selectedSpeed: $selectedSpeed,
                thumbSize: thumbSize,
                coordinateSpace: coordinateSpace
            )
        }
        .coordinateSpace(.named("speed"))
        .opacity(viewModel.showContent ? 1 : 0)
        .animation(.default, value: viewModel.showContent)
        .padding(borderWidth)
        .accessibilityElement(children: .combine)
        .accessibilityValue(String(format: "%.1f", selectedSpeed))
        .accessibilityLabel("playbackSpeed")
        .accessibilityAdjustableAction(handleAccessibilitySpeedChange)
    }

    func handleAccessibilitySpeedChange(_ direction: AccessibilityAdjustmentDirection) {
        let speeds = Const.speeds
        if let currentIndex = speeds.firstIndex(of: selectedSpeed) {
            var newIndex = currentIndex
            switch direction {
            case .increment:
                newIndex = min(currentIndex + 1, speeds.count - 1)
            case .decrement:
                newIndex = max(currentIndex - 1, 0)
            default:
                break
            }
            selectedSpeed = speeds[newIndex]
            viewModel.setThumbPosition(to: selectedSpeed)
        }
    }

    func getSelectedSpeed(_ tappedSpeed: Double) -> Double {
        // get speed or highlighted speed only if tapped speed is right next to it
        if Device.isMac {
            return tappedSpeed
        }
        let index = Const.speeds.firstIndex(of: tappedSpeed) ?? 0
        let highlightIndeces = Const.highlightedSpeedsInt
            .compactMap { Const.speeds.firstIndex(of: $0) }

        if highlightIndeces.contains(index) {
            return tappedSpeed
        }
        let match = highlightIndeces.filter { index == $0 - 1 || index == $0 + 1 }
        guard let first = match.first else {
            return tappedSpeed
        }
        return Const.speeds[first]
    }

    func onSpeedTap(_ speed: Double) {
        withAnimation {
            selectedSpeed = getSelectedSpeed(speed)
            viewModel.setThumbPosition(to: selectedSpeed)
            viewModel.resetDragState()
        }
    }
}

struct SpeedPreferenceKey: PreferenceKey {
    static var defaultValue: CGRect { .zero }
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

#Preview {
    @Previewable @State var selected: Double = 1.3

    SpeedControlView(selectedSpeed: $selected)
        .modelContainer(DataProvider.previewContainer)
        .environment(NavigationManager())
        .frame(width: 100)
    // .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
}
