//
//  PlaybackSpeedControl.swift
//  Unwatched
//

import SwiftUI

struct SpeedControlView: View {
    @Binding var selectedSpeed: Double
    static let speeds: [Double] = [1, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 2]
    let highlighted: [Double] = [1, 1.5, 2]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15.0)
                .fill(Color.backgroundGray)
                .frame(height: 50)
                .frame(maxWidth: .infinity)

            HStack(spacing: 0) {
                ForEach(SpeedControlView.speeds, id: \.self) { speed in
                    let isHightlighted = highlighted.contains(speed)
                    let isSelected = speed == selectedSpeed

                    let maxFrameSize: CGFloat = 34
                    let frameSize: CGFloat = isSelected ? maxFrameSize : isHightlighted ? 22 : 8
                    let cornerRadius: CGFloat = isSelected ? 12 : isHightlighted ? 7 : 2
                    let backgroundColor: Color = isSelected ? .myAccentColor : .clear
                    let foregroundColor: Color = isSelected ? .backgroundColor : .foregroundGray
                    let showStroke = !isSelected
                    let fontSize: CGFloat = isSelected ? 17 : 12

                    ZStack {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                self.selectedSpeed = speed
                            }
                            .frame(width: maxFrameSize, height: maxFrameSize)
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(showStroke ? foregroundColor : .clear, lineWidth: 1.5)
                            .fill(backgroundColor)
                            .frame(width: frameSize, height: frameSize)
                            .onTapGesture(perform: {self.selectedSpeed = speed})
                        if isHightlighted || isSelected {
                            Text(SpeedControlView.formatSpeed(speed))
                                .foregroundStyle(foregroundColor)
                                .fontWeight(.medium)
                                .font(.system(size: fontSize))
                        }
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    static func formatSpeed(_ speed: Double) -> String {
        if floor(speed) == speed {
            return String(format: "%.0f", speed)
        } else {
            return String(format: "%.1f", speed)
        }
    }
}

struct SpeedControlView_Previews: PreviewProvider {
    @State static var speed: Double = 1.0

    static var previews: some View {
        SpeedControlView(selectedSpeed: $speed)
    }
}

#Preview {
    SpeedControlView(selectedSpeed: .constant(1.5))
        .modelContainer(DataController.previewContainer)
}
