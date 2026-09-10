//
//  VolumeControl.swift
//  UnwatchedWatch
//

import AVFoundation
import SwiftUI
import UnwatchedShared
import WatchKit

/// The system's volume control, mounted where it cannot be seen.
///
/// There is no API to set the watch's volume ourselves (`AVAudioSession.outputVolume` is
/// read-only) and the Digital Crown does nothing for playback in a third-party app until a
/// `WKInterfaceVolumeControl` holds its focus — so the object has to exist, and it has to be
/// focused. What it does *not* have to be is visible: measured on the watch, a control drawn at
/// ~zero alpha in a 1pt frame still takes crown input. Only `.hidden()` breaks it, since SwiftUI
/// drops it from the layout altogether. That leaves the round speaker button off the screen and
/// the value free to be drawn as a bar beside the crown, the way Now Playing does it.
struct VolumeControl: View {
    /// Whether this screen is the one the crown should be turning. The player is a page in a tab
    /// view and the queue beside it scrolls, so focus has to be handed back when it isn't showing.
    let isActive: Bool
    /// `.local` is the watch's own output, `.companion` the iPhone's.
    let origin: WKInterfaceVolumeControl.Origin

    var body: some View {
        Representable(isActive: isActive, origin: origin)
            // The origin is fixed when the object is made, so switching player means a new one.
            .id(origin)
            // Small enough to be nowhere, present enough to keep focus.
            .frame(width: 1, height: 1)
            .opacity(0.001)
            .allowsHitTesting(false)
    }

    private struct Representable: WKInterfaceObjectRepresentable {
        let isActive: Bool
        let origin: WKInterfaceVolumeControl.Origin

        func makeWKInterfaceObject(context: Context) -> WKInterfaceVolumeControl {
            WKInterfaceVolumeControl(origin: origin)
        }

        func updateWKInterfaceObject(_ control: WKInterfaceVolumeControl, context: Context) {
            // Only on a change, rather than on every update: the player screen redraws every second
            // while the remaining time ticks, and re-taking a focus we already hold is wasted work.
            guard context.coordinator.isFocused != isActive else { return }
            context.coordinator.isFocused = isActive
            if isActive {
                control.focus()
            } else {
                control.resignFocus()
            }
        }

        func makeCoordinator() -> Coordinator {
            Coordinator()
        }

        final class Coordinator {
            /// Starts as neither, so the first update always acts.
            var isFocused: Bool?
        }
    }
}

/// Where the volume is, for anyone drawing it.
///
/// The crown turns the volume through the control above without telling the app anything, but
/// `outputVolume` does report what it lands on — on the watch itself. The phone's is not readable
/// here, so the phone sends it and `update` takes it. On the simulator the property is a stub that
/// never moves, so this looks broken there and isn't.
@MainActor
@Observable
final class WatchVolume {
    private(set) var volume: Double = Double(AVAudioSession.sharedInstance().outputVolume)
    /// True for a moment after each change, which is the whole basis for showing the indicator:
    /// the crown belongs to the volume control, so SwiftUI never sees the rotation itself.
    private(set) var isAdjusting = false
    /// Which side the bar comes from. The crown is on the left for a watch worn on the right
    /// wrist, and sliding out of the opposite edge to the finger turning it looks like a mistake.
    /// Read afresh on each change rather than once: the wearer can flip it in Settings while the
    /// app is still running.
    private(set) var crownOrientation = WKInterfaceDevice.current().crownOrientation

    @ObservationIgnored private var observation: NSKeyValueObservation?
    @ObservationIgnored private var hide: Task<Void, Never>?

    /// How long the bar stays up after the last change. Long enough to read after a slow quarter
    /// turn, short enough not to sit on top of the artwork.
    private static let linger = Duration.seconds(1.5)

    /// The watch's own output. Not while the phone is playing: its volume is what the crown turns.
    func startLocal() {
        guard observation == nil else { return }
        let session = AVAudioSession.sharedInstance()
        volume = Double(session.outputVolume)
        observation = session.observe(\.outputVolume, options: [.new]) { [weak self] _, change in
            guard let value = change.newValue else { return }
            Task { @MainActor in
                self?.update(Double(value))
            }
        }
    }

    func stopLocal() {
        observation = nil
    }

    func update(_ value: Double) {
        volume = value
        crownOrientation = WKInterfaceDevice.current().crownOrientation
        isAdjusting = true
        hide?.cancel()
        hide = Task { [weak self] in
            try? await Task.sleep(for: Self.linger)
            guard !Task.isCancelled else { return }
            self?.isAdjusting = false
        }
    }
}

/// The indicator itself: a vertical bar for the slot beside the crown.
///
/// The fill is not animated. The system's volume moves in steps of about a sixteenth and easing
/// across one only adds travel between the crown and the bar — at this size a step is a couple of
/// points, which lands better than it interpolates. The slide is animated explicitly: an accessory
/// is drawn outside the view's own hierarchy, so an `.animation` further up the player never
/// reaches it.
struct VolumeAccessory: View {
    let volume: Double
    let isVisible: Bool
    let crownOrientation: WKInterfaceDeviceCrownOrientation

    var body: some View {
        Capsule()
            .fill(.white.opacity(0.25))
            .overlay(alignment: .bottom) {
                Capsule()
                    .fill(.white)
                    .frame(height: max(Self.width, Self.height * volume))
            }
            .frame(width: Self.width, height: Self.height)
            // It slides out of the edge it belongs to and back into it, rather than appearing in
            // place: the bar reads as the crown's own, arriving from where your finger is. Far
            // enough past the edge to be clipped by it, so nothing is left on the bezel.
            .offset(x: isVisible ? 0 : Self.width * 3 * (crownOrientation == .left ? -1 : 1))
            .animation(.easeInOut(duration: Self.slide), value: isVisible)
    }

    private static let slide: TimeInterval = 0.35
    private static let width: CGFloat = 6
    private static let height: CGFloat = 30
}
