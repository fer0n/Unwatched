//
//  CircularProgressView.swift
//  Unwatched
//

import SwiftUI

struct CircularProgressView: View {
    @Binding var progress: Double
    var size: Double = 20
    var lineWidth: Double = 5

    let timer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    var stops: [Double] = []

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    Color.primary.opacity(0.2),
                    lineWidth: lineWidth
                )
            Circle()
                .trim(from: 0, to: max(0.01, progress))
                .stroke(
                    Color.primary,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut, value: progress)
        }
        .frame(width: size, height: size)
        .onReceive(timer) { _ in
            let nextStop = stops.first(where: { $0 > progress }) ?? 1
            let distance = nextStop - progress
            // Step is 20% of the remaining distance, with a minimum of 0.005 and maximum of 0.06
            let step = max(0.001, min(0.01, distance * 0.05))
            let newValue = progress + step
            if newValue < nextStop {
                progress = newValue
            }
        }
    }
}

#Preview {
    // 1
    @Previewable @State var progress: Double = 0.3

    VStack {
        Spacer()
        ZStack {
            CircularProgressView(progress: $progress, stops: [0.25, 0.9, 1])
        }.frame(width: 200, height: 200)
        Spacer()
        HStack {
            // 4
            Slider(value: $progress, in: 0...1)
            // 5
            Button("reset") {
                progress = 0
            }.buttonStyle(.borderedProminent)
        }
    }
}
