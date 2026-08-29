//
//  CombinedPlaybackSpeedSetting.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct CombinedPlaybackSpeedSettingPlayer: View {
    @Environment(PlayerManager.self) var player

    @State var hapticToggle: Bool = false
    var spacing: CGFloat = 10
    var showTemporarySpeed = false
    var hasHaptics = true
    var isTransparent = true

    var body: some View {
        @Bindable var player = player
        let isOn = Binding(get: {
            player.video?.subscription?.customSpeedSetting != nil
        }, set: { value in
            player.video?.subscription?.customSpeedSetting = value ? player.defaultPlaybackSpeed : nil
            hapticToggle.toggle()
        })

        CombinedPlaybackSpeedSetting(
            selectedSpeed: $player.debouncedPlaybackSpeed,
            isOn: isOn,
            hapticToggle: $hapticToggle,
            hasHaptics: hasHaptics,
            spacing: spacing,
            showTemporarySpeed: showTemporarySpeed,
            isTransparent: isTransparent
        )
        .onChange(of: player.video?.subscription) {
            // workaround
        }
        .overlay {
            if player.temporaryPlaybackSpeed != nil {
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                player.temporaryPlaybackSpeed = nil
                            }
                    )
            }
        }
    }
}

struct CombinedPlaybackSpeedSetting: View {
    @ScaledMetric var controlHeight: CGFloat = PlayerToggleModifier.baseSmallSize

    @Binding var selectedSpeed: Double
    @Binding var isOn: Bool
    @Binding var hapticToggle: Bool

    let borderWidth: CGFloat = 2
    var hasHaptics = true

    var spacing: CGFloat = 10
    var showTemporarySpeed = false
    var isTransparent = true

    var body: some View {
        HStack(spacing: spacing) {
            InlineSpeedControl(
                selectedSpeed: $selectedSpeed,
                isOn: $isOn,
                height: controlHeight,
                borderWidth: borderWidth,
                showTemporarySpeed: showTemporarySpeed,
                isTransparent: isTransparent
            )
        }
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle) { _, _ in
            return hasHaptics
        }
    }
}

/// Vertically scrollable speed selection next to the custom speed setting toggle, sharing one background.
/// Tapping the speed opens a menu that stays open while stepping, picking a common speed
/// or restricting the speed to the current channel.
struct InlineSpeedControl: View {
    @Environment(PlayerManager.self) var player

    @Binding var selectedSpeed: Double
    @Binding var isOn: Bool

    @State private var isInteracting = false

    var height: CGFloat
    var borderWidth: CGFloat = 2
    var showTemporarySpeed = false
    var isTransparent = true

    var body: some View {
        HStack(spacing: 0) {
            CustomSettingsButton(isOn: $isOn)
                .toggleStyle(
                    CustomSettingsToggleStyle(
                        imageOn: Const.customPlaybackSpeedSF,
                        imageOff: Const.customPlaybackSpeedOffSF
                    )
                )
                .disabled(player.video?.subscription == nil || hasTempSpeed)
                .padding(.leading, 3)
                .padding(.trailing, -5)

            SpeedMenu(
                selectedSpeed: $selectedSpeed,
                isOn: $isOn,
                canSetCustomSpeed: player.video?.subscription != nil
            ) {
                FullscreenSpeedControlContent(
                    value: selectedSpeed,
                    onChange: { selectedSpeed = $0 },
                    triggerInteraction: { },
                    isInteracting: $isInteracting,
                    fontSize: 18,
                    fontWidth: .standard,
                    frameWidth: 50
                )
                .foregroundStyle(Color.automaticBlack)
                .frame(maxHeight: .infinity)
                .padding(.trailing, 2)
            }
            .buttonStyle(.plain)
            // no `disabled` while a temporary speed is set: toggling it rebuilds the label, which
            // resets the speed's scroll position. Taps are caught by the overlay in the player variant.
            .accessibilityLabel(accessibilityLabel)

            if showTemporarySpeed {
                Button {
                    player.toggleTemporaryPlaybackSpeed()
                } label: {
                    Image(systemName: "waveform")
                        .font(.title3)
                        .speedSettingsImageStyle(
                            isOn: hasTempSpeed,
                            imageOn: "gauge.with.needle.fill",
                            imageOff: "gauge.with.needle"
                        )
                }
                .buttonStyle(.plain)
                .help("temporarySpeed")
                .accessibilityLabel("temporarySpeed")
            }
        }
        .font(.system(size: 18))
        .fontWidth(.condensed)
        .fontWeight(.semibold)
        .padding(borderWidth)
        .frame(height: height)
        .speedSelectionBackground(isTransparent: isTransparent)
        #if !os(visionOS)
        .playerControlBackground(in: Capsule())
        #endif
        .fixedSize(horizontal: true, vertical: false)
    }

    var hasTempSpeed: Bool {
        player.temporaryPlaybackSpeed != nil
    }

    var accessibilityLabel: String {
        let speedText = SpeedHelper.formatSpeed(selectedSpeed)
        return String(localized: "playbackSpeed \(speedText)")
    }
}

/// Shows the speed selection anchored to `label`, keeping it open while stepping through speeds.
/// A menu can't stay open on macOS, so a popover with hand-built entries is used there instead.
struct SpeedMenu<Label: View>: View {
    @Binding var selectedSpeed: Double
    @Binding var isOn: Bool

    var canSetCustomSpeed = true
    var usePopover = false
    var arrowEdge: Edge?
    var onPopoverChange: ((Bool) -> Void)?
    @ViewBuilder var label: () -> Label

    @Environment(\.colorScheme) var colorScheme
    @State private var showPopover = false

    @Namespace private var namespace
    private let transitionId = "speedPopoverTransition"

    var showsPopover: Bool {
        #if os(macOS)
        true
        #else
        usePopover
        #endif
    }

    var body: some View {
        if showsPopover {
            popoverVariant
        } else {
            menuVariant
        }
    }

    // no button style: each call site brings its own, same as the menu below
    var popoverVariant: some View {
        Button {
            showPopover.toggle()
        } label: {
            label()
        }
        .modifier(MyMatchedTransitionSource(id: transitionId, namespace: namespace))
        .popover(isPresented: $showPopover, arrowEdge: arrowEdge ?? .top) {
            SpeedPopoverContent(
                selectedSpeed: $selectedSpeed,
                isOn: $isOn,
                canSetCustomSpeed: canSetCustomSpeed
            )
            .presentationCompactAdaptation(.popover)
            // the popover doesn't inherit the app's appearance
            .environment(\.colorScheme, colorScheme)
            #if os(iOS) || os(visionOS)
            .navigationTransition(
                .zoom(sourceID: transitionId, in: namespace)
            )
            #else
            .presentationBackground(Color.backgroundColor)
            #endif
        }
        .onChange(of: showPopover) {
            onPopoverChange?(showPopover)
        }
    }

    var menuVariant: some View {
        Menu {
            SpeedMenuContent(
                selectedSpeed: $selectedSpeed,
                isOn: $isOn,
                canSetCustomSpeed: canSetCustomSpeed
            )
        } label: {
            label()
        }
        .menuIndicator(.hidden)
        .environment(\.menuOrder, .fixed)
        #if !os(macOS)
        .menuActionDismissBehavior(.disabled)
        #endif
    }
}

/// `SpeedMenu` bound to the currently playing video
struct PlayerSpeedMenu<Label: View>: View {
    @Environment(PlayerManager.self) var player

    var usePopover = false
    var arrowEdge: Edge?
    var onPopoverChange: ((Bool) -> Void)?
    @ViewBuilder var label: () -> Label

    var body: some View {
        @Bindable var player = player
        let isOn = Binding(get: {
            player.video?.subscription?.customSpeedSetting != nil
        }, set: { value in
            player.video?.subscription?.customSpeedSetting = value ? player.defaultPlaybackSpeed : nil
        })

        SpeedMenu(
            selectedSpeed: $player.debouncedPlaybackSpeed,
            isOn: isOn,
            canSetCustomSpeed: player.video?.subscription != nil,
            usePopover: usePopover,
            arrowEdge: arrowEdge,
            onPopoverChange: onPopoverChange,
            label: label
        )
    }
}

/// Menu entries to select the playback speed: a stepper for fine adjustments,
/// the most common speeds and the toggle to restrict the speed to the current channel.
struct SpeedMenuContent: View {
    @Binding var selectedSpeed: Double
    @Binding var isOn: Bool

    var canSetCustomSpeed = true

    /// Speeds offered in the menu; the player's speed control scrolls through all of them
    let menuSpeeds: [Double] = [1, 1.3, 1.5, 2]

    var body: some View {
        // the menu shows neutral system colors instead of inheriting the app's theme tint
        Group {
            speedStepper

            ControlGroup {
                ForEach(menuSpeeds, id: \.self) { speed in
                    Button {
                        selectedSpeed = speed
                    } label: {
                        Text(verbatim: "\(SpeedHelper.formatSpeed(speed))×")
                    }
                    .disabled(speed == selectedSpeed)
                }
            }
            .controlGroupStyle(.compactMenu)

            Divider()
            customSettingButton
        }
        .tint(nil)
    }

    /// Compact row stepping through all speeds, with the current one in the middle.
    /// The id keeps it apart from the speeds below: menu entries are diffed by title,
    /// so a duplicate would silently be moved instead of inserted.
    var speedStepper: some View {
        ControlGroup {
            Button {
                if let speed = SpeedHelper.getPreviousSpeed(before: selectedSpeed) {
                    selectedSpeed = speed
                }
            } label: {
                Image(systemName: "minus")
            }
            .accessibilityLabel("slowDown")

            Button {
                // shows the current speed, no action
            } label: {
                Text(SpeedHelper.formatSpeed(selectedSpeed))
            }
            .id("currentSpeed")

            Button {
                if let speed = SpeedHelper.getNextSpeed(after: selectedSpeed) {
                    selectedSpeed = speed
                }
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("speedUp")
        }
        .controlGroupStyle(.compactMenu)
    }

    var customSettingButton: some View {
        Button {
            isOn.toggle()
        } label: {
            Label(
                "customSpeedSetting",
                systemImage: isOn ? Const.customPlaybackSpeedSF : Const.customPlaybackSpeedOffSF
            )
        }
        .disabled(!canSetCustomSpeed)
    }
}

extension View {
    public func speedSelectionBackground(isTransparent: Bool = true) -> some View {
        self.background {
            Capsule()
                .fill(Color.backgroundColor.opacity(isTransparent ? 0.5 : 1))
        }
    }
}

#Preview {
    @Previewable @State var isOn = false
    @Previewable @State var selectedSpeed: Double = 1

    CombinedPlaybackSpeedSetting(
        selectedSpeed: $selectedSpeed,
        isOn: $isOn,
        hapticToggle: .constant(
            true
        ),
        showTemporarySpeed: true
    )
    .modelContainer(DataProvider.previewContainer)
    .environment(PlayerManager.getDummy())
    .environment(NavigationManager())
    .frame(width: 350)
}
