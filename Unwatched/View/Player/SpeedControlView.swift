//
//  PlaybackSpeedControl.swift
//  Unwatched
//

import SwiftUI

struct SpeedControlView: View {
    @Binding var selectedSpeed: Double
    static let speeds: [Double] = [1, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 2]
    let highlighted: [Double] = [1, 1.5, 2]

    static let padding: CGFloat = 0
    static let maxHeight: CGFloat = 40
    static let midY: CGFloat = SpeedControlView.maxHeight / 2

    let frameHeight: CGFloat = 30
    let coordinateSpace: NamedCoordinateSpace = .named("speed")
    @State var hapticToggle = false
    @State var width: CGFloat = 0
    @State var itemWidth: CGFloat = 0

    @State var controlMinX: CGFloat?
    @State private var dragState: CGFloat?

    var body: some View {
        ZStack {
            Capsule()
                .fill(Color.backgroundGray)
                .frame(height: frameHeight)
                .frame(maxWidth: .infinity)

            HStack(spacing: 0) {
                ForEach(SpeedControlView.speeds, id: \.self) { speed in
                    let isHightlighted = highlighted.contains(speed)
                    let frameSize: CGFloat = isHightlighted ? 20 : 5
                    let foregroundColor: Color = .foregroundGray

                    ZStack {
                        Circle()
                            .fill()
                            .stroke(foregroundColor, lineWidth: 1.5)
                            .foregroundStyle(isHightlighted ? .clear : foregroundColor)
                            .frame(width: frameSize, height: frameSize)
                            .frame(maxWidth: .infinity, maxHeight: SpeedControlView.maxHeight)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation {
                                    selectedSpeed = speed
                                    controlMinX = getXPos(width, selectedSpeed)
                                    hapticToggle.toggle()
                                }
                            }
                        if isHightlighted {
                            Text(SpeedControlView.formatSpeed(speed))
                                .fontWeight(.medium)
                                .font(.system(size: 10))
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
                self.width = minY.width
                self.itemWidth = width / CGFloat(SpeedControlView.speeds.count)
                controlMinX = getXPos(width, selectedSpeed)
            }
            .padding(.horizontal, SpeedControlView.padding)

            if let controlMinX = controlMinX {
                ZStack {
                    Circle()
                        .fill()
                        .frame(width: SpeedControlView.maxHeight, height: SpeedControlView.maxHeight)
                    Text(getFloatingText())
                        .foregroundStyle(.black)
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
            controlMinX = getXPos(width, selectedSpeed)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 2, coordinateSpace: coordinateSpace)
                .onChanged { gesture in
                    let dragPosition = (controlMinX ?? 0) + gesture.translation.width
                    let cappedMax = max(dragPosition, SpeedControlView.padding + (itemWidth / 2))
                    dragState = min(cappedMax, width - (SpeedControlView.padding + (itemWidth / 2)))
                }
                .onEnded { state in
                    let value = state.translation.width
                    let currentPos = (controlMinX ?? 0) + value
                    let selected = getSpeedFromPos(currentPos)
                    controlMinX = currentPos
                    selectedSpeed = selected

                    withAnimation {
                        controlMinX = getXPos(width, selected)
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
            return SpeedControlView.formatSpeed(selectedSpeed) + "x"
        }
        let speed = getSpeedFromPos(dragState ?? 0)
        return SpeedControlView.formatSpeed(speed) + "x"
    }

    func getSpeedFromPos(_ pos: CGFloat) -> Double {
        let itemWidth = width / CGFloat(SpeedControlView.speeds.count)
        let calculatedIndex = Int(round((pos / itemWidth) - 0.5) )
        let index = max(0, min(calculatedIndex, SpeedControlView.speeds.count - 1))
        let speed = SpeedControlView.speeds[index]
        return speed
    }

    func getXPos(_ fullWidth: CGFloat, _ speed: CGFloat) -> CGFloat {
        let selectedSpeedIndex = SpeedControlView.speeds.firstIndex(of: speed) ?? 0
        return SpeedControlView.padding + (CGFloat(selectedSpeedIndex) * itemWidth) + (itemWidth / 2)
    }

    static func formatSpeed(_ speed: Double) -> String {
        if floor(speed) == speed {
            return String(format: "%.0f", speed)
        } else {
            return String(format: "%.1f", speed)
        }
    }
}

struct SpeedPreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
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
            .padding()
    }
}

#Preview {
    SpeedControlViewPreview()
}
