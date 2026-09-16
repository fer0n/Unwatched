//
//  SpeedMenuContent.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

/// Menu entries to select the playback speed: a stepper for fine adjustments,
/// the most common speeds and the toggles to restrict the speed to the current channel
/// and to trim silence.
struct SpeedMenuContent: View {
    @Binding var selectedSpeed: Double
    @Binding var isOn: Bool

    var canSetCustomSpeed = true
    var trimSilence: TrimSilenceOption?

    /// Speeds offered in the menu; the player's speed control scrolls through all of them
    static let menuSpeeds: [Double] = [1, 1.3, 1.5, 2]

    var body: some View {
        // the menu shows neutral system colors instead of inheriting the app's theme tint
        Group {
            speedStepper

            ControlGroup {
                ForEach(Self.menuSpeeds, id: \.self) { speed in
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
            if let trimSilence {
                TrimSilenceMenuEntry(isOn: trimSilence.isOn)
                    .disabled(!trimSilence.isEnabled)
            }
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
