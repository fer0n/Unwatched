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
    @State private var gestureScrubberWidth: CGFloat = 0

    init(
        height: CGFloat? = nil,
        inlineTime: Bool = false,
        translucent: Bool = false,
        glassEffect: Bool = true,
        fillColor: Color = .foregroundGray,
        trackColor: Color = .white,
        timeColor: Color = .secondary,
        verticalHitSlop: CGFloat = 5,
        onScrubbingChanged: ((Bool) -> Void)? = nil
    ) {
        self.inlineTime = inlineTime
        self.scrubberHeight = height ?? 20
        self.translucent = translucent
        self.glassEffect = glassEffect
        self.fillColor = fillColor
        self.trackColor = trackColor
        self.timeColor = timeColor
        self.verticalHitSlop = verticalHitSlop
        self.onScrubbingChanged = onScrubbingChanged
    }

    let inlineTime: Bool
    let translucent: Bool
    let glassEffect: Bool
    let fillColor: Color
    let trackColor: Color
    let timeColor: Color
    var onScrubbingChanged: ((Bool) -> Void)?
    let scrubbingPadding: CGFloat = 8
    let inactiveHeight: CGFloat = 150
    /// Extra vertical touch area added on each side of the scrubber without affecting layout.
    let verticalHitSlop: CGFloat

    let enableTapScrubbing: Bool = Device.isMac
    var scrubberHeight: CGFloat

    var body: some View {
        let boundedPosition = getWithinBounds(draggedScrubberWidth, maxValue: scrubberWidth)
        let currentScrubberPosition = boundedPosition

        VStack(spacing: 1) {
            if !inlineTime {
                HStack {
                    Text(formattedCurrentTime)
                        .animation(nil, value: UUID())
                        .matchedGeometryEffect(id: "currentTime", in: namespace)

                    Spacer()

                    Text(formattedDuration)
                        .matchedGeometryEffect(id: "totalTime", in: namespace)
                }
                .padding(.horizontal, scrubbingPadding)
                .foregroundStyle(timeColor)
                .font(.caption.monospacedDigit())
            }

            HStack {
                if inlineTime {
                    Text(formattedCurrentTime)
                        .animation(nil, value: UUID())
                        .foregroundStyle(timeColor)
                        .font(.caption.monospacedDigit())
                        .fixedSize()
                        .matchedGeometryEffect(id: "currentTime", in: namespace)
                }

                ZStack {
                    if translucent {
                        trackColor
                            .opacity(0.4)
                    } else {
                        trackColor
                            .opacity(isGestureActive ? 0.15 : 0.1)
                    }
                }
                .onSizeChange { geometry in
                    viewSize = geometry
                }
                .overlay {
                    if let video = player.video,
                       let total = video.duration {

                        HStack(spacing: 0) {
                            fillColor
                                .opacity(isGestureActive ? 0.8 : 0.6)
                                .frame(width: currentScrubberPosition)
                            Color.clear
                        }

                        ProgressBarChapterIndicators(
                            video: player.video,
                            height: currentScrubberHeight,
                            width: scrubberWidth,
                            duration: total
                        )
                    }
                }
                .frame(height: currentScrubberHeight)
                .clipShape(clipShape)
                .shadow(color: Color.black.opacity(0.15), radius: 4)
                #if os(visionOS)
                .contentShape(.hoverEffect, .capsule)
                .hoverEffect()
                #else
                .apply {
                if glassEffect {
                $0.glassEffect(.regular, in: clipShape)
                } else {
                $0
                }
                }
                #endif
                .frame(height: scrubberHeight)
                .padding(.vertical, verticalHitSlop)
                .contentShape(Rectangle())
                #if os(visionOS)
                .overlay {
                    let anchor = CGPoint(
                        x: currentScrubberPosition,
                        y: -currentScrubberHeight / 3
                    )

                    CurrentChapterPopup(
                        isVisible: isGestureActive,
                        chapterTitle: (player.currentChapterPreview?.title ?? player.currentChapter?.title),
                        currentTime: formattedCurrentTime,
                        anchor: anchor
                    )
                }
                #endif
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: enableTapScrubbing ? .local : .global)
                        .onChanged(handleChanged)
                        .onEnded(handleEnded)
                )
                .disabled(isDisabled)
                .padding(.vertical, -verticalHitSlop)
                #if os(iOS) || os(visionOS)
                .animation(.default.speed(2), value: currentScrubberHeight)
                #endif

                if inlineTime {
                    Text(formattedDuration)
                        .foregroundStyle(timeColor)
                        .font(.caption.monospacedDigit())
                        .fixedSize()
                        .matchedGeometryEffect(id: "totalTime", in: namespace)
                }
            }
        }
        .sensoryFeedback(
            Const.sensoryFeedback,
            trigger: initialDragPosition
        ) { $1 != nil }
        .sensoryFeedback(Const.sensoryFeedback, trigger: isGestureActive)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "playerScrubber"))
        .accessibilityAdjustableAction(handleAccessibilitySpeedChange)
        .accessibilityValue(currentTime?.formattedSecondsColon ?? "")
    }

    var currentScrubberHeight: CGFloat {
        scrubberHeight - (isGestureActive ? 0 : 2)
    }

    var clipShape: some Shape {
        Capsule()
    }

    var isDisabled: Bool {
        player.video?.duration == nil
    }

    var scrubberWidth: CGFloat {
        max(0, viewSize.width)
    }

    var currentScrubberWidth: CGFloat {
        getCurrentPosition() ?? 0
    }

    var draggedScrubberWidth: CGFloat {
        isInactive ? currentScrubberWidth : (initialDragPosition ?? currentScrubberWidth) + dragOffset
    }

    var currentTime: Double? {
        if isGestureActive,
           let time = getTimeFromPosition(draggedScrubberWidth),
           let duration = player.video?.duration {
            let value = getWithinBounds(time, maxValue: CGFloat(duration))
            return Double(value)
        }

        return player.currentTime
    }

    var formattedDuration: String {
        player.video?.duration?.formattedSecondsColon ?? ""
    }

    var formattedCurrentTime: String {
        #if os(visionOS)
        player.video != nil
            ? currentTime?.getFormattedSecondsColon(
                player.video?.duration ?? currentTime ?? 0
            ) ?? ""
            : ""
        #else
        player.video != nil ? currentTime?.formattedSecondsColon ?? "" : ""
        #endif
    }

    func handleAccessibilitySpeedChange(_ direction: AccessibilityAdjustmentDirection) {
        switch direction {
        case .increment:
            _ = player.seekForward(15)
        case .decrement:
            _ = player.seekBackward(15)
        default:
            break
        }
    }

    func handleChanged(_ value: DragGesture.Value) {
        isGestureActive = true
        if initialDragPosition == nil {
            gestureScrubberWidth = scrubberWidth
            onScrubbingChanged?(true)
            if enableTapScrubbing {
                if value.translation == .zero {
                    // Initial click - move to clicked position
                    let position = max(0, min(value.location.x, scrubberWidth))
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
                let position = max(0, min(value.location.x, scrubberWidth))
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
        onScrubbingChanged?(false)
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
        let width = isGestureActive ? gestureScrubberWidth : scrubberWidth
        if width > 0, let video = player.video, let total = video.duration {
            return Double(position / width) * total
        }
        return nil
    }
}

#Preview {
    let player = PlayerManager.getDummy()
    player.currentTime = 140

    return PlayerScrubber()
        .frame(width: 300, height: 150)
        .environment(player)
    //     .testEnvironments()
}
