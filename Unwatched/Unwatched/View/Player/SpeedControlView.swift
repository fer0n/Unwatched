//
//  PlaybackSpeedControl.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct SpeedControlView: View {
    @Environment(NavigationManager.self) private var navManager

    @State var viewModel = SpeedControlViewModel()
    @State var controlMinX: CGFloat?
    @State private var dragState: CGFloat?

    @Binding var selectedSpeed: Double

    @ScaledMetric var thumbSize: CGFloat = 35
    @ScaledMetric var selectedFontSize: CGFloat = 17
    let frameHeight: CGFloat = 35
    let coordinateSpace: NamedCoordinateSpace = .named("speed")
    let borderWidth: CGFloat = 2
    var indicatorSpacing: CGFloat = 2

    var midY: CGFloat {
        thumbSize / 2
    }

    var body: some View {
        let highlighted: [Double] = viewModel.showDecimalHighlights
            ? Const.highlightedPlaybackSpeeds
            : Const.highlightedSpeedsInt
        let frameSize: CGFloat = 3

        ZStack {
            Spacer()
                .frame(height: frameHeight)
                .frame(maxWidth: .infinity)

            HStack(spacing: 0) {
                ForEach(Const.speeds, id: \.self) { speed in
                    let isHightlighted = highlighted.contains(speed)
                    let foregroundColor: Color = .foregroundGray.opacity(0.5)

                    ZStack {
                        Circle()
                            .fill(isHightlighted ? .clear : foregroundColor)
                            .foregroundStyle(isHightlighted ? .clear : foregroundColor)
                            .frame(width: frameSize, height: frameSize)
                            .frame(maxWidth: .infinity, maxHeight: thumbSize)
                            .frame(minWidth: frameSize + indicatorSpacing)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation {
                                    selectedSpeed = getSelectedSpeed(speed)
                                    controlMinX = viewModel.getXPos(selectedSpeed)
                                    dragState = nil
                                }
                            }
                        if isHightlighted {
                            Text(SpeedControlViewModel.formatSpeed(speed))
                                .font(.system(size: 12))
                                .fontWeight(.heavy)
                                .fontWidth(.compressed)
                                .foregroundStyle(foregroundColor)
                                .allowsHitTesting(false)
                                .frame(minWidth: 10)
                                .frame(width: frameSize, height: frameSize)
                        }
                    }
                }
            }
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
                    controlMinX = viewModel.getXPos(selectedSpeed)
                    if !viewModel.showContent {
                        viewModel.showContent = true
                    }
                }
            }

            thumb
        }
        .onChange(of: selectedSpeed) {
            if dragState == nil {
                controlMinX = viewModel.getXPos(selectedSpeed)
            }
        }
        .onChange(of: navManager.showMenu) {
            if dragState != nil {
                withAnimation {
                    dragState = nil
                }
            }
        }
        .coordinateSpace(.named("speed"))
        .opacity(viewModel.showContent ? 1 : 0)
        .animation(.default, value: viewModel.showContent)
        .padding(borderWidth)
    }

    var thumbBackground: some View {
        Circle()
            .fill()
            .frame(width: thumbSize, height: thumbSize)
    }

    @ViewBuilder var thumb: some View {
        if let controlMinXLocal = controlMinX {
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
            .geometryGroup()
            .position(x: dragState ?? controlMinXLocal, y: midY)
            .frame(maxHeight: thumbSize)
            .animation(.bouncy(duration: 0.4), value: controlMinX)
            .transition(.identity)
            .gesture(dragThumbGesture)
        }
    }

    var dragThumbGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: coordinateSpace)
            .onChanged { gesture in
                let dragPosition = (controlMinX ?? 0) + gesture.translation.width
                let cappedMax = max(dragPosition, viewModel.padding + (viewModel.itemWidth / 2))
                dragState = min(
                    cappedMax,
                    viewModel.width - (viewModel.padding + (viewModel.itemWidth / 2))
                )
            }
            .onEnded { state in
                let value = state.translation.width

                // allow clicking "underneath" the thumb
                let currentPos = abs(value) <= 3
                    ? state.location.x
                    : (controlMinX ?? 0) + value

                let selected = viewModel.getSpeedFromPos(currentPos)
                controlMinX = currentPos
                selectedSpeed = selected

                withAnimation {
                    controlMinX = viewModel.getXPos(selected)
                    dragState = nil
                }
            }
    }

    func getFloatingText() -> String {
        let speed = dragState == nil
            ? selectedSpeed
            : viewModel.getSpeedFromPos(dragState ?? 0)
        let text = SpeedControlViewModel.formatSpeed(speed)
        handleDebounceSpeedChange(speed)
        return text + (text.count <= 2 ? "×" : "")
    }

    func handleDebounceSpeedChange(_ speed: Double) {
        if dragState != nil, speed != viewModel.currentSpeed {
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
}

struct SpeedPreferenceKey: PreferenceKey {
    static var defaultValue: CGRect { .zero }
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

struct SpeedControlView_Previews: PreviewProvider {
    @State static var speed: Double = 1.0

    static var previews: some View {
        SpeedControlView(selectedSpeed: $speed)
            .environment(NavigationManager())
    }
}

struct SpeedControlViewPreview: View {
    @State var selected: Double = 1.3

    var body: some View {
        SpeedControlView(selectedSpeed: $selected)
            .modelContainer(DataProvider.previewContainer)
            .environment(NavigationManager())
    }
}

#Preview {
    SpeedControlViewPreview()
        .frame(width: 100)
    // .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
}
