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
    @ScaledMetric var selectedFontSize: CGFloat = 16
    let frameHeight: CGFloat = 35
    let coordinateSpace: NamedCoordinateSpace = .named("speed")
    let borderWidth: CGFloat = 2

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
                    let foregroundColor: Color = .foregroundGray.opacity(0.3)

                    ZStack {
                        Circle()
                            .fill()
                            .stroke(isHightlighted ? .clear : foregroundColor, lineWidth: 1.5)
                            .foregroundStyle(isHightlighted ? .clear : foregroundColor)
                            .frame(width: frameSize, height: frameSize)
                            .frame(maxWidth: .infinity, maxHeight: thumbSize)
                            .frame(minWidth: frameSize + 4)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation {
                                    selectedSpeed = speed
                                    controlMinX = viewModel.getXPos(selectedSpeed)
                                    dragState = nil
                                }
                            }
                        if isHightlighted {
                            Text(SpeedControlViewModel.formatSpeed(speed))
                                .fontWeight(.bold)
                                .font(.custom("SFCompactDisplay-Semibold", size: 12))
                                .foregroundStyle(foregroundColor)
                                .allowsHitTesting(false)
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
            controlMinX = viewModel.getXPos(selectedSpeed)
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
        .background {
            Capsule()
                .fill(Color.backgroundColor)
        }
    }

    @ViewBuilder var thumb: some View {
        if let controlMinXLocal = controlMinX {
            let floatingText = getFloatingText()
            ZStack {
                Circle()
                    .fill()
                    .frame(width: thumbSize, height: thumbSize)
                Text(floatingText)
                    .foregroundStyle(.automaticWhite)
                    .font(.custom("SFCompactDisplay-Bold", size: selectedFontSize))
                    .sensoryFeedback(Const.sensoryFeedback, trigger: floatingText)
            }
            .position(x: dragState ?? controlMinXLocal, y: midY)
            .frame(maxHeight: thumbSize)
            .animation(.bouncy(duration: 0.4), value: controlMinX)
            .transition(.identity)
            .gesture(dragThumbGesture)
        }
    }

    var dragThumbGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: coordinateSpace)
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
                let currentPos = (controlMinX ?? 0) + value
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
        return text + (text.count <= 2 ? "×" : "")
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
        // .padding()
    }
}

#Preview {
    SpeedControlViewPreview()
        .frame(width: 300)
    // .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
}
