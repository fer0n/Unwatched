//
//  BackgroundProgressBar.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct PlayerScrubber: View {
    @Namespace var namespace

    @Environment(PlayerManager.self) var player

    @State private var dragOffset: CGFloat = 0
    @State private var initialDragPosition: CGFloat?
    @State private var viewSize: CGSize = .zero
    @State private var isInactive: Bool = false
    @State private var isGestureActive = false

    init(limitHeight: Bool = false, inlineTime: Bool = false) {
        self.inlineTime = inlineTime
        self.scrubberHeight = limitHeight ? 10 : 20
    }

    let inlineTime: Bool
    let thumbWidth: CGFloat = 4
    let scrubbingPadding: CGFloat = 8
    let inactiveHeight: CGFloat = 150

    let enableTapScrubbing: Bool = Device.isMac
    var scrubberHeight: CGFloat

    var body: some View {
        let boundedPosition = getWithinBounds(draggedScrubberWidth, maxValue: scrubberWidth)
        let currentScrubberPosition = scrubbingPadding + boundedPosition

        VStack(spacing: 2) {
            if !inlineTime {
                HStack {
                    Text(formattedCurrentTime)
                        .matchedGeometryEffect(id: "currentTime", in: namespace)
                        .contentTransition(.numericText(countsDown: false))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(formattedCurrentTime == " " ? " " : formattedDuration)
                        .matchedGeometryEffect(id: "totalTime", in: namespace)
                        .contentTransition(.numericText(countsDown: false))
                }
                .animation(.default.speed(1), value: formattedCurrentTime == " ")
                .padding(.horizontal, scrubbingPadding)
                .foregroundStyle(.secondary)
                .font(.caption)
            }

            HStack {
                if inlineTime {
                    Text(formattedCurrentTime)
                        .foregroundStyle(.secondary)
                        .font(.subheadline.monospacedDigit())
                        .fixedSize()
                        .matchedGeometryEffect(id: "currentTime", in: namespace)
                        .animation(.default, value: formattedCurrentTime == " ")
                        .contentTransition(.numericText(countsDown: true))
                }

                ZStack {
                    Color.foregroundGray.opacity(0.2)

                    if let video = player.video,
                       let total = video.duration {

                        HStack(spacing: 0) {
                            Color.foregroundGray
                                .opacity(0.3)
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
                .animation(.default.speed(3), value: isInactive)

                if inlineTime {
                    Text(formattedDuration)
                        .foregroundStyle(.secondary)
                        .font(.subheadline.monospacedDigit())
                        .contentTransition(.numericText(countsDown: true))
                        .fixedSize()
                        .matchedGeometryEffect(id: "totalTime", in: namespace)
                }
            }
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
        guard inlineTime || (!player.isPlaying || initialDragPosition != nil || isGestureActive) else {
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

    var formattedDuration: String {
        player.video?.duration?.formattedSecondsColon ?? " "
    }

    var formattedCurrentTime: String {
        currentTime?.formattedSecondsColon ?? " "
    }

    func handleChanged(_ value: DragGesture.Value) {
        isGestureActive = true
        if initialDragPosition == nil {
            if enableTapScrubbing {
                if value.translation == .zero {
                    // Initial click - move to clicked position
                    let position = max(0, min(value.location.x - scrubbingPadding, scrubberWidth))
                    if let duration = player.video?.duration,
                       let newTime = getTimeFromPosition(position) {
                        let floatDuration = CGFloat(duration)
                        let cleanedTime = getWithinBounds(newTime, maxValue: floatDuration)
                        player.seek(to: cleanedTime)
                        player.currentTime = cleanedTime
                        player.handleChapterChange()
                    }
                }
                // Set initial position for dragging
                let position = max(0, min(value.location.x - scrubbingPadding, scrubberWidth))
                initialDragPosition = position
            } else {
                initialDragPosition = getCurrentPosition()
            }
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
            player.seek(to: cleanedTime)
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
                width: thumbWidth * (!isGestureActive ? 1 : 1.4),
                height: scrubberHeight * (!isGestureActive ? 1 : 1.3)
            )
            .sensoryFeedback(
                Const.sensoryFeedback,
                trigger: initialDragPosition
            ) { $1 != nil }
            .sensoryFeedback(Const.sensoryFeedback, trigger: isGestureActive)
    }
}

#Preview {
    PlayerScrubber(limitHeight: false)
        .frame(height: 150)
        .environment(PlayerManager.getDummy())
}
