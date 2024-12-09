//
//  BackgroundProgressBar.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct PlayerScrubber: View {
    @Environment(PlayerManager.self) var player

    @State private var dragOffset: CGFloat = 0
    @State private var initialDragPosition: CGFloat?
    @State private var viewSize: CGSize = .zero
    @State private var isInactive: Bool = false
    @State private var isGestureActive = false

    let thumbWidth: CGFloat = 4
    let scrubbingPadding: CGFloat = 8
    let inactiveHeight: CGFloat = 150

    var scrubberHeight: CGFloat = 20

    var body: some View {
        let boundedPosition = getWithinBounds(draggedScrubberWidth, maxValue: scrubberWidth)
        let currentScrubberPosition = scrubbingPadding + boundedPosition

        VStack(spacing: 5) {
            HStack {
                Text(formattedCurrentTime)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .animation(.default, value: formattedCurrentTime == " ")

                if let duration = player.video?.duration?.formattedSecondsColon {
                    Text(duration)
                }
            }
            .padding(.horizontal, scrubbingPadding)
            .foregroundStyle(.secondary)
            .font(.caption)

            ZStack {
                Color.clear
                    .background(Color.backgroundColor)

                if let video = player.video,
                   let total = video.duration {

                    HStack(spacing: 0) {
                        Color.foregroundGray
                            .opacity(0.2)
                            .frame(width: currentScrubberPosition)
                        Color.clear
                    }

                    ProgressBarChapterIndicators(
                        video: player.video,
                        height: scrubberHeight,
                        width: scrubberWidth,
                        duration: total
                    )
                    .padding(.horizontal, scrubbingPadding)
                }
            }
            .onSizeChange { geometry in
                viewSize = geometry
            }
            .frame(height: scrubberHeight)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged(handleChanged)
                    .onEnded(handleEnded)
            )
            .overlay {
                thumb
                    .position(
                        x: currentScrubberPosition,
                        y: scrubberHeight / 2
                    )
            }
            .disabled(isDisabled)
            .animation(.default, value: currentScrubberWidth)
            .animation(.default.speed(3), value: isInactive)
        }
    }

    var isDisabled: Bool {
        player.video?.duration == nil
    }

    var scrubberWidth: CGFloat {
        max(0, viewSize.width - scrubbingPadding * 2)
    }

    var currentScrubberWidth: CGFloat {
        getCurrentPosition() ?? 0
    }

    var draggedScrubberWidth: CGFloat {
        isInactive ? currentScrubberWidth : (initialDragPosition ?? currentScrubberWidth) + dragOffset
    }

    var currentTime: Double? {
        guard !player.isPlaying || initialDragPosition != nil || isGestureActive else {
            return nil
        }

        if isGestureActive,
           let time = getTimeFromPosition(draggedScrubberWidth),
           let duration = player.video?.duration {
            let value = getWithinBounds(time, maxValue: CGFloat(duration))
            return Double(value)
        }

        return player.currentTime
    }

    var formattedCurrentTime: String {
        currentTime?.formattedSecondsColon ?? " "
    }

    func handleChanged(_ value: DragGesture.Value) {
        isGestureActive = true

        if initialDragPosition == nil && value.translation.width.magnitude > 0 {
            initialDragPosition = getCurrentPosition()
            isInactive = true
        } else {
            isInactive = value.translation.height.magnitude > inactiveHeight
        }

        dragOffset = value.translation.width

        if isInactive {
            player.currentChapterPreview = nil
        } else if let initialDragPosition,
                  let time = getTimeFromPosition(initialDragPosition + dragOffset) {
            player.setCurrentChapterPreview(at: time)
        }
    }

    func handleEnded(_ value: DragGesture.Value) {
        if !isInactive,
           let initialDragPosition,
           let duration = player.video?.duration,
           let newTime = getTimeFromPosition(initialDragPosition + dragOffset) {
            let floatDuration = CGFloat(duration)
            let cleanedTime = getWithinBounds(newTime, maxValue: floatDuration)
            player.seekAbsolute = cleanedTime
            player.currentTime = cleanedTime
            player.handleChapterChange()
        }

        player.currentChapterPreview = nil
        initialDragPosition = nil
        isInactive = false
        isGestureActive = false
        dragOffset = 0
    }

    func getWithinBounds(_ value: CGFloat, maxValue: CGFloat? = nil) -> CGFloat {
        let lowerBound = max(value, 0)
        if let maxValue {
            return min(maxValue, lowerBound)
        }
        return lowerBound
    }

    func getCurrentPosition() -> CGFloat? {
        if let elapsed = player.currentTime,
           let video = player.video,
           let total = video.duration {
            return (elapsed / total) * scrubberWidth
        }
        return nil
    }

    func getTimeFromPosition(_ position: CGFloat) -> Double? {
        if let video = player.video, let total = video.duration {
            return Double(position / scrubberWidth) * total
        }
        return nil
    }

    var thumb: some View {
        Capsule()
            .fill(
                isDisabled || isInactive || (isGestureActive && initialDragPosition == nil)
                    ? .foregroundGray
                    : Color.automaticBlack
            )
            .frame(
                width: thumbWidth * (!isGestureActive ? 1 : 1.8),
                height: scrubberHeight * (!isGestureActive ? 1 : 1.2)
            )
            .animation(.default, value: isGestureActive)
            .sensoryFeedback(
                Const.sensoryFeedback,
                trigger: initialDragPosition
            ) { $1 != nil }
            .sensoryFeedback(Const.sensoryFeedback, trigger: isGestureActive)
    }
}

#Preview {
    PlayerScrubber()
        .frame(height: 150)
        .environment(PlayerManager.getDummy())
}
