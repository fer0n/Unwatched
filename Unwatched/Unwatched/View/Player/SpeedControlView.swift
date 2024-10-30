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

    nonisolated static let padding: CGFloat = 8
    @ScaledMetric var maxHeight: CGFloat = 40
    @ScaledMetric var selectedFontSize: CGFloat = 16
    let frameHeight: CGFloat = 25
    let coordinateSpace: NamedCoordinateSpace = .named("speed")

    var body: some View {
        let highlighted: [Double] = viewModel.showDecimalHighlights
            ? Const.highlightedPlaybackSpeeds
            : Const.highlightedSpeedsInt

        ZStack {
            let midY: CGFloat = maxHeight / 2

            Capsule()
                .fill(Color.backgroundGray)
                .frame(height: frameHeight)
                .frame(maxWidth: .infinity)

            HStack(spacing: 0) {
                ForEach(Const.speeds, id: \.self) { speed in
                    let isHightlighted = highlighted.contains(speed)
                    let frameSize: CGFloat = 5
                    let foregroundColor: Color = .foregroundGray

                    ZStack {
                        Circle()
                            .fill()
                            .stroke(isHightlighted ? .clear : foregroundColor, lineWidth: 1.5)
                            .foregroundStyle(isHightlighted ? .clear : foregroundColor)
                            .frame(width: frameSize, height: frameSize)
                            .frame(maxWidth: .infinity, maxHeight: maxHeight)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation {
                                    selectedSpeed = speed
                                    controlMinX = viewModel.getXPos(viewModel.width, selectedSpeed)
                                    dragState = nil
                                }
                            }
                        if isHightlighted {
                            Text(SpeedControlViewModel.formatSpeed(speed))
                                .fontWeight(.bold)
                                .font(.custom("SFCompactDisplay-Semibold", size: 12))
                                .foregroundStyle(foregroundColor)
                        }
                    }
                }
            }
            .overlay {
                GeometryReader { geometry in
                    Color.clear.preference(key: SpeedPreferenceKey.self, value: geometry.frame(in: coordinateSpace))
                }
            }
            .onPreferenceChange(SpeedPreferenceKey.self) { minY in
                viewModel.width = minY.width
                viewModel.itemWidth = viewModel.width / CGFloat(Const.speeds.count)
                controlMinX = viewModel.getXPos(viewModel.width, selectedSpeed)
            }
            .padding(.horizontal, SpeedControlView.padding)

            if let controlMinX = controlMinX {
                let floatingText = getFloatingText()
                ZStack {
                    Circle()
                        .fill()
                        .frame(width: maxHeight, height: maxHeight)
                    Text(floatingText)
                        .foregroundStyle(.automaticWhite)
                        .font(.system(size: selectedFontSize, weight: .bold))
                        .sensoryFeedback(Const.sensoryFeedback, trigger: floatingText)
                }
                .position(x: dragState ?? controlMinX, y: midY)
                .frame(maxHeight: maxHeight)
                .animation(.bouncy(duration: 0.4), value: controlMinX)
                .transition(.identity)
            }
        }
        .onChange(of: selectedSpeed) {
            controlMinX = viewModel.getXPos(viewModel.width, selectedSpeed)
        }
        .onChange(of: navManager.showMenu) {
            if dragState != nil {
                withAnimation {
                    dragState = nil
                }
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 2, coordinateSpace: coordinateSpace)
                .onChanged { gesture in
                    let dragPosition = (controlMinX ?? 0) + gesture.translation.width
                    let cappedMax = max(dragPosition, SpeedControlView.padding + (viewModel.itemWidth / 2))
                    dragState = min(cappedMax, viewModel.width + SpeedControlView.padding - (viewModel.itemWidth / 2))
                }
                .onEnded { state in
                    let value = state.translation.width
                    let currentPos = (controlMinX ?? 0) + value
                    let selected = viewModel.getSpeedFromPos(currentPos)
                    controlMinX = currentPos
                    selectedSpeed = selected

                    withAnimation {
                        controlMinX = viewModel.getXPos(viewModel.width, selected)
                        dragState = nil
                    }
                }
        )
        .coordinateSpace(.named("speed"))
        .padding(.horizontal, 5)
    }

    func getFloatingText() -> String {
        let speed = dragState == nil
            ? selectedSpeed
            : viewModel.getSpeedFromPos(dragState ?? 0)
        let text = SpeedControlViewModel.formatSpeed(speed)
        return text + (text.count <= 1 ? "×" : "")
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
            .modelContainer(DataController.previewContainer)
            .environment(NavigationManager())
            .padding()
    }
}

#Preview {
    SpeedControlViewPreview()
        .frame(width: 250)
    // .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
}
