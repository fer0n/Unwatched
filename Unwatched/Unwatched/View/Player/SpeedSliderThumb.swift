//
//  SpeedSliderThumb.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct SpeedSliderThumb: View {
    @Environment(NavigationManager.self) private var navManager
    @ScaledMetric var selectedFontSize: CGFloat = 17

    @Binding var viewModel: SpeedControlViewModel
    @Binding var selectedSpeed: Double

    var thumbSize: CGFloat
    let coordinateSpace: NamedCoordinateSpace

    var body: some View {
        thumb
            .onChange(of: selectedSpeed) {
                if viewModel.dragState == nil && selectedSpeed != viewModel.currentSpeed {
                    viewModel.setThumbPosition(to: selectedSpeed)
                }
            }
            .onChange(of: navManager.showMenu) {
                if viewModel.dragState != nil {
                    withAnimation {
                        viewModel.resetDragState()
                    }
                }
            }
    }

    var thumbBackground: some View {
        Circle()
            .fill()
            .frame(width: thumbSize, height: thumbSize)
    }

    @ViewBuilder var thumb: some View {
        if let controlMinXLocal = viewModel.controlMinX {
            let floatingText = getFloatingText()
            ZStack {
                // if #available(iOS 26, *) {
                //     thumbBackground
                //         .glassEffect(.regular.tint(.white).interactive())
                // } else {
                thumbBackground
                // }
                Text(floatingText)
                    .foregroundStyle(.automaticWhite)
                    .font(.system(size: selectedFontSize))
                    .sensoryFeedback(Const.sensoryFeedback, trigger: floatingText)
                    .fontWidth(.condensed)
                    .fontWeight(.heavy)
            }
            .fixedSize()
            .geometryGroup()
            .position(x: viewModel.dragState ?? controlMinXLocal, y: midY)
            .frame(maxHeight: thumbSize)
            .animation(.bouncy(duration: 0.4), value: viewModel.controlMinX)
            .gesture(dragThumbGesture)
        }
    }

    var dragThumbGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: coordinateSpace)
            .onChanged { gesture in
                let dragPosition = (viewModel.controlMinX ?? 0) + gesture.translation.width
                let cappedMax = max(dragPosition, viewModel.padding + (viewModel.itemWidth / 2))
                viewModel.dragState = min(
                    cappedMax,
                    viewModel.width - (viewModel.padding + (viewModel.itemWidth / 2))
                )
            }
            .onEnded { state in
                let value = state.translation.width

                // allow clicking "underneath" the thumb
                let currentPos = abs(value) <= 3
                    ? state.location.x
                    : (viewModel.controlMinX ?? 0) + value

                var selected = viewModel.getSpeedFromPos(currentPos)
                viewModel.controlMinX = currentPos
                selected = viewModel.getSelectedSpeed(selected)
                selectedSpeed = selected

                withAnimation {
                    viewModel.setThumbPosition(to: selected)
                    viewModel.dragState = nil
                }
            }
    }

    var midY: CGFloat {
        thumbSize / 2
    }

    func getFloatingText() -> String {
        let speed = viewModel.dragState == nil
            ? selectedSpeed
            : viewModel.getSpeedFromPos(viewModel.dragState ?? 0)
        let text = SpeedControlViewModel.formatSpeed(speed)
        handleDebounceSpeedChange(speed)
        return text + (text.count <= 2 ? "×" : "")
    }

    func handleDebounceSpeedChange(_ speed: Double) {
        if viewModel.dragState != nil, speed != viewModel.currentSpeed {
            viewModel.currentSpeed = speed
            viewModel.speedDebounceTask?.cancel()
            viewModel.speedDebounceTask = Task {
                do {
                    try await Task.sleep(for: .milliseconds(500))
                    selectedSpeed = speed
                    viewModel.speedDebounceTask = nil
                } catch {}
            }
        }
    }
}
