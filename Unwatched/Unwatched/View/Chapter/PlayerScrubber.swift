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
    let scrubbingPadding: CGFloat = 8
    let inactiveHeight: CGFloat = 150

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
                .foregroundStyle(.secondary)
                .font(.caption.monospacedDigit())
            }

            HStack {
                if inlineTime {
                    Text(formattedCurrentTime)
                        .animation(nil, value: UUID())
                        .foregroundStyle(.secondary)
                        .font(.caption.monospacedDigit())
                        .fixedSize()
                        .matchedGeometryEffect(id: "currentTime", in: namespace)
                }

                ZStack {
                    Color.foregroundGray.opacity(Const.iOS26
                                                    ? (isGestureActive ? 0.15 : 0.1)
                                                    : (isGestureActive ? 0.25 : 0.2))

                    if let video = player.video,
                       let total = video.duration {

                        HStack(spacing: 0) {
                            Color.foregroundGray
                                .opacity(isGestureActive ? 0.5 : 0.3)
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
                .onSizeChange { geometry in
                    viewSize = geometry
                }
                .frame(height: currentScrubberHeight)
                .clipShape(clipShape)
                .apply {
                    if #available(iOS 26.0, macOS 26.0, *) {
                        $0.glassEffect(.regular, in: clipShape)
                    } else {
                        $0
                    }
                }
                .frame(height: scrubberHeight)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged(handleChanged)
                        .onEnded(handleEnded)
                )
                .disabled(isDisabled)
                #if os(iOS)
                .animation(.default.speed(2), value: currentScrubberHeight)
                #endif

                if inlineTime {
                    Text(formattedDuration)
                        .foregroundStyle(.secondary)
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
        currentTime?.formattedSecondsColon ?? ""
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
}

#Preview {
    let player = PlayerManager.getDummy()
    player.currentTime = 33230

    return PlayerScrubber(limitHeight: false)
        .frame(height: 150)
        .environment(player)
}
