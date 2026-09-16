//
//  SpeedPopoverContent.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

/// Speed selection shown in a popover: a stepper for fine adjustments,
/// the most common speeds and the toggles to restrict the speed to the current channel and
/// to trim silence. Unlike `SpeedMenuContent` this stays open while stepping through speeds.
struct SpeedPopoverContent: View {
    @Binding var selectedSpeed: Double
    @Binding var isOn: Bool

    var canSetCustomSpeed = true
    var trimSilence: TrimSilenceOption?

    /// Speeds offered directly; the speed control scrolls through all of them
    let quickSpeeds: [Double] = [1, 1.3, 1.5, 2]

    let itemHeight: CGFloat = 36
    let spacing: CGFloat = 6

    static let shapeOpacity: CGFloat = 0.5
    static let selectedShapeOpacity: CGFloat = 0.7

    var body: some View {
        VStack(spacing: spacing) {
            stepper
            quickSpeedRow
            customSettingButton
            if let trimSilence {
                trimSilenceButton(trimSilence)
            }
        }
        .frame(minWidth: 210)
        .padding(spacing * 2)
        .buttonStyle(.plain)
        .sensoryFeedback(Const.sensoryFeedback, trigger: selectedSpeed)
        .sensoryFeedback(Const.sensoryFeedback, trigger: isOn)
    }

    var stepper: some View {
        HStack(spacing: spacing) {
            stepButton("minus", label: "slowDown") {
                SpeedHelper.getPreviousSpeed(before: selectedSpeed)
            }

            Text(verbatim: "\(SpeedHelper.formatSpeed(selectedSpeed))×")
                .font(.system(size: 17))
                .fontWeight(.semibold)
                .contentTransition(.numericText())
                .foregroundStyle(Color.automaticBlack)
                .frame(maxWidth: .infinity)
                .animation(.default, value: selectedSpeed)

            stepButton("plus", label: "speedUp") {
                SpeedHelper.getNextSpeed(after: selectedSpeed)
            }
        }
    }

    func stepButton(
        _ systemImage: String,
        label: LocalizedStringKey,
        nextSpeed: @escaping () -> Double?
    ) -> some View {
        Button {
            if let speed = nextSpeed() {
                selectedSpeed = speed
            }
        } label: {
            Image(systemName: systemImage)
                .font(.body)
                .fontWeight(.bold)
                .foregroundStyle(Color.automaticBlack)
                .frame(width: itemHeight * 1.4, height: itemHeight)
                .background(Color.insetBackgroundColor.opacity(Self.shapeOpacity), in: .capsule)
        }
        .disabled(nextSpeed() == nil)
        .accessibilityLabel(label)
    }

    var quickSpeedRow: some View {
        HStack(spacing: spacing) {
            ForEach(quickSpeeds, id: \.self) { speed in
                Button {
                    selectedSpeed = speed
                } label: {
                    Text(verbatim: "\(SpeedHelper.formatSpeed(speed))×")
                        .font(.system(size: 15))
                        .fontWeight(.semibold)
                        .fontWidth(.condensed)
                        .frame(maxWidth: .infinity)
                        .frame(height: itemHeight)
                        .modifier(SpeedPopoverItemStyle(isOn: speed == selectedSpeed))
                }
            }
        }
    }

    func trimSilenceButton(_ option: TrimSilenceOption) -> some View {
        optionButton(
            "trimSilence",
            image: option.isOn.wrappedValue ? Const.trimSilenceSF : Const.trimSilenceOffSF,
            isOn: option.isOn.wrappedValue,
            subtitle: {
                TrimSilenceSavedText()
                    .font(.caption)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            },
            action: { option.isOn.wrappedValue.toggle() }
        )
        .enabled(option.isEnabled)
    }

    var customSettingButton: some View {
        optionButton(
            "customSpeedSetting",
            image: isOn ? Const.customPlaybackSpeedSF : Const.customPlaybackSpeedOffSF,
            isOn: isOn,
            subtitle: { },
            action: { isOn.toggle() }
        )
        .enabled(canSetCustomSpeed)
    }

    func optionButton<Subtitle: View>(
        _ title: LocalizedStringKey,
        image: String,
        isOn: Bool,
        @ViewBuilder subtitle: () -> Subtitle,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                HStack(spacing: spacing) {
                    Image(systemName: image)
                        .contentTransition(.symbolEffect(.replace))
                    Text(title)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .font(.system(size: 15))
                .fontWeight(.semibold)

                subtitle()
            }
            .padding(.vertical, spacing)
            .padding(.horizontal, itemHeight / 3)
            .frame(maxWidth: .infinity)
            .frame(minHeight: itemHeight)
            .modifier(SpeedPopoverItemStyle(isOn: isOn))
        }
    }
}

private extension View {
    func enabled(_ isEnabled: Bool) -> some View {
        disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.4)
    }
}

struct SpeedPopoverItemStyle: ViewModifier {
    let isOn: Bool

    func body(content: Content) -> some View {
        content
            .foregroundStyle(isOn ? Color.backgroundColor : Color.automaticBlack)
            .background(
                isOn
                    ? Color.neutralAccentColor.opacity(SpeedPopoverContent.selectedShapeOpacity)
                    : Color.insetBackgroundColor.opacity(SpeedPopoverContent.shapeOpacity),
                in: .capsule
            )
            .animation(.default, value: isOn)
    }
}

#Preview {
    @Previewable @State var selectedSpeed: Double = 1.5
    @Previewable @State var isOn = false

    // sized and backed like it would be inside a popover
    SpeedPopoverContent(selectedSpeed: $selectedSpeed, isOn: $isOn)
        .fixedSize()
        .background(Color.backgroundColor)
}
