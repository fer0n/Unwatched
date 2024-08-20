//
//  PlaybackSpeedControl.swift
//  Unwatched
//

import SwiftUI

struct SpeedControlView: View {
    @Environment(NavigationManager.self) private var navManager

    @State var viewModel = SpeedControlViewModel()
    @State var hapticToggle = false
    @State var controlMinX: CGFloat?
    @State private var dragState: CGFloat?

    @Binding var selectedSpeed: Double

    let highlighted: [Double] = Const.highlightedPlaybackSpeeds
    static let padding: CGFloat = 0
    static let maxHeight: CGFloat = 40
    static let midY: CGFloat = SpeedControlView.maxHeight / 2
    let frameHeight: CGFloat = 30
    let coordinateSpace: NamedCoordinateSpace = .named("speed")

    var body: some View {
        ZStack {
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
                            .frame(maxWidth: .infinity, maxHeight: SpeedControlView.maxHeight)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation {
                                    selectedSpeed = speed
                                    controlMinX = viewModel.getXPos(viewModel.width, selectedSpeed)
                                    hapticToggle.toggle()
                                    dragState = nil
                                }
                            }
                        if isHightlighted {
                            Text(SpeedControlViewModel.formatSpeed(speed))
                                .fontWeight(.bold)
                                .font(.system(size: 12))
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
                ZStack {
                    Circle()
                        .fill()
                        .frame(width: SpeedControlView.maxHeight, height: SpeedControlView.maxHeight)
                    Text(getFloatingText())
                        .foregroundStyle(.automaticWhite)
                        .bold()
                        .font(.system(size: 16))
                }
                .position(x: dragState ?? controlMinX, y: SpeedControlView.midY)
                .frame(maxHeight: SpeedControlView.maxHeight)
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
                    dragState = min(cappedMax, viewModel.width - (SpeedControlView.padding + (viewModel.itemWidth / 2)))
                }
                .onEnded { state in
                    let value = state.translation.width
                    let currentPos = (controlMinX ?? 0) + value
                    let selected = viewModel.getSpeedFromPos(currentPos)
                    controlMinX = currentPos
                    selectedSpeed = selected

                    withAnimation {
                        controlMinX = viewModel.getXPos(viewModel.width, selected)
                        hapticToggle.toggle()
                        dragState = nil
                    }
                }
        )
        .coordinateSpace(.named("speed"))
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
        .padding(.horizontal, 5)
    }

    func getFloatingText() -> String {
        if dragState == nil {
            return SpeedControlViewModel.formatSpeed(selectedSpeed) + "×"
        }
        let speed = viewModel.getSpeedFromPos(dragState ?? 0)
        return SpeedControlViewModel.formatSpeed(speed) + "×"
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
    }
}

struct SpeedControlViewPreview: View {
    @State var selected: Double = 1.5

    var body: some View {
        SpeedControlView(selectedSpeed: $selected)
            .modelContainer(DataController.previewContainer)
            .environment(NavigationManager())
            .padding()
    }
}

#Preview {
    SpeedControlViewPreview()
}
