//
//  SubscriptionSkipSetting.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

/// Which end of a video the setting trims, see `ChapterService.applySkipIntro`/`applySkipOutro`.
enum SkipEdge {
    case intro
    case outro

    var label: LocalizedStringKey {
        self == .intro ? "skipIntro" : "skipOutro"
    }

    var systemImage: String {
        self == .intro ? "forward.end.circle" : "arrow.forward.to.line.circle"
    }

    var seconds: ReferenceWritableKeyPath<Subscription, Double?> {
        self == .intro ? \.skipIntroSeconds : \.skipOutroSeconds
    }
}

struct SubscriptionSkipSetting: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.settingControlStyle) var style

    var subscription: Subscription
    var edge: SkipEdge

    @State private var showPopover = false
    @Namespace private var namespace

    private var transitionId: String {
        "skipPopoverTransition-\(edge)"
    }

    var body: some View {
        let seconds = Binding(
            get: {
                subscription[keyPath: edge.seconds] ?? 0
            }, set: { value in
                subscription[keyPath: edge.seconds] = value > 0 ? value : nil
            }
        )

        if style == .menuItem {
            let isOff = seconds.wrappedValue == 0

            CapsulePicker(
                selection: seconds,
                options: Self.menuOptions(including: seconds.wrappedValue),
                label: { (SkipPopoverContent.text(for: $0), edge.systemImage) },
                menuLabel: edge.label,
                hidesMenuValue: isOff
            )
            .requiresPremium(isOff, feature: "skipIntroOutro")
        } else {
            popoverButton(seconds: seconds)
        }
    }

    static func menuOptions(including seconds: Double) -> [Double] {
        let presets: [Double] = [0, 5, 10, 15, 20, 30, 45, 60, 90]
        return presets.contains(seconds) ? presets : (presets + [seconds]).sorted()
    }

    func popoverButton(seconds: Binding<Double>) -> some View {
        Button {
            showPopover.toggle()
        } label: {
            CapsuleMenuLabel(
                systemImage: edge.systemImage,
                menuLabel: edge.label,
                text: SkipPopoverContent.text(for: seconds.wrappedValue)
            )
        }
        .buttonStyle(CapsuleButtonStyle(primary: false))
        .requiresPremium(seconds.wrappedValue == 0, feature: "skipIntroOutro")
        .modifier(MyMatchedTransitionSource(id: transitionId, namespace: namespace))
        .popover(isPresented: $showPopover, arrowEdge: .top) {
            SkipPopoverContent(seconds: seconds, edge: edge)
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
    }
}

/// How much of the intro or outro to skip, stepped a second at a time.
struct SkipPopoverContent: View {
    @Binding var seconds: Double
    var edge: SkipEdge

    private let itemHeight: CGFloat = 36
    private let spacing: CGFloat = 6
    private let range: ClosedRange<Double> = 0...300

    static func text(for seconds: Double) -> String {
        seconds > 0 ? "\(Int(seconds))s" : String(localized: "off")
    }

    var body: some View {
        VStack(spacing: spacing) {
            Text(edge.label)
                .font(.system(size: 15))
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            stepper
        }
        .frame(minWidth: 210)
        .padding(spacing * 2)
        .buttonStyle(.plain)
        .sensoryFeedback(Const.sensoryFeedback, trigger: seconds)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(edge.label)
        .accessibilityValue(Self.text(for: seconds))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: step(to: seconds + 1)
            case .decrement: step(to: seconds - 1)
            default: break
            }
        }
    }

    private var stepper: some View {
        HStack(spacing: spacing) {
            stepButton("minus") { seconds - 1 }

            Text(verbatim: Self.text(for: seconds))
                .font(.system(size: 17))
                .fontWeight(.semibold)
                .contentTransition(.numericText())
                .foregroundStyle(Color.automaticBlack)
                .frame(maxWidth: .infinity)
                .animation(.default, value: seconds)

            stepButton("plus") { seconds + 1 }
        }
    }

    private func stepButton(_ systemImage: String, next: @escaping () -> Double) -> some View {
        Button {
            step(to: next())
        } label: {
            Image(systemName: systemImage)
                .font(.body)
                .fontWeight(.bold)
                .foregroundStyle(Color.automaticBlack)
                .frame(width: itemHeight * 1.4, height: itemHeight)
                .background(
                    Color.insetBackgroundColor.opacity(SpeedPopoverContent.shapeOpacity),
                    in: .capsule
                )
        }
        .buttonRepeatBehavior(.enabled)
        .disabled(!range.contains(next()))
    }

    private func step(to value: Double) {
        guard range.contains(value) else { return }
        seconds = value
    }
}

#Preview {
    SubscriptionSkipSetting(subscription: Subscription.getDummy(), edge: .intro)
}

#Preview("Popover content") {
    @Previewable @State var seconds: Double = 0

    // sized and backed like it would be inside a popover
    SkipPopoverContent(seconds: $seconds, edge: .outro)
        .fixedSize()
        .background(Color.backgroundColor)
}
