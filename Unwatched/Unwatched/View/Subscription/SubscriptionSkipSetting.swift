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

/// Which SponsorBlock category a per-channel override applies to.
enum SegmentCategory {
    case sponsor
    case selfPromo

    var label: LocalizedStringKey {
        self == .sponsor ? "sponsorSegments" : "selfPromoSegments"
    }

    var systemImage: String {
        self == .sponsor ? "dollarsign" : "megaphone.fill"
    }

    var setting: ReferenceWritableKeyPath<Subscription, SponsorBlockSegmentSetting?> {
        self == .sponsor ? \.sponsorSegmentSetting : \.selfPromoSegmentSetting
    }
}

/// Overrides the global setting for one segment category, for this channel only.
struct SubscriptionSegmentSetting: View {
    @CloudStorage(Const.sponsorSegmentSetting)
    var globalSponsor: SponsorBlockSegmentSetting = SponsorBlockSegmentSetting.sponsorDefault
    @CloudStorage(Const.selfPromoSegmentSetting)
    var globalSelfPromo: SponsorBlockSegmentSetting = SponsorBlockSegmentSetting.selfPromoDefault
    @CloudStorage(Const.youtubePremium) var youtubePremium: Bool = false

    var subscription: Subscription
    var category: SegmentCategory

    var body: some View {
        let selection = Binding(
            get: {
                subscription[keyPath: category.setting]
            }, set: { value in
                subscription[keyPath: category.setting] = value
            }
        )

        CapsulePicker(
            selection: selection,
            options: options,
            label: {
                let text = $0?.description ?? String(localized: "defaultSegmentSetting \(globalSetting.description)")
                let img = $0?.systemImage ?? globalSetting.systemImage
                return (text, img)
            },
            menuLabel: category.label
        )
    }

    private var globalSetting: SponsorBlockSegmentSetting {
        category == .sponsor ? globalSponsor : globalSelfPromo
    }

    private var options: [SponsorBlockSegmentSetting?] {
        let settings = SponsorBlockSegmentSetting.allCases
            .filter { youtubePremium || !$0.skips }
        return [nil] + settings.map { $0 }
    }
}

/// The chapter titles this channel skips automatically, and a way to stop skipping one.
struct SubscriptionAutoSkipSetting: View {
    @CloudStorage(Const.autoSkipRecurringChapters) var autoSkipRecurringChapters: Bool = true

    var subscription: Subscription

    var body: some View {
        let titles = subscription.autoSkipChapterTitles ?? []

        if autoSkipRecurringChapters, !titles.isEmpty {
            Menu {
                Section("autoSkipChaptersHelper") {
                    ForEach(titles, id: \.self) { title in
                        Button(role: .destructive) {
                            subscription.setAutoSkip(title, false)
                        } label: {
                            Label(title, systemImage: Const.clearNoFillSF)
                        }
                    }
                }
            } label: {
                CapsuleMenuLabel(
                    systemImage: "forward.circle.fill",
                    menuLabel: "autoSkipChapters",
                    text: "\(titles.count)"
                )
            }
            .menuIndicator(.hidden)
            .buttonStyle(CapsuleButtonStyle(primary: false))
        }
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
