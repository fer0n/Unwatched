//
//  CapsuleLabel.swift
//  Unwatched
//

import SwiftUI

/// The single-line label of a capsule button: an icon and a value on one line.
struct CapsuleLabel<Icon: View>: View {
    var text: String
    @ViewBuilder var icon: Icon

    @Environment(\.settingControlStyle) var style
    @Environment(\.chipContentColor) var chipContentColor
    @Environment(\.chipIconColor) var chipIconColor

    var body: some View {
        switch style {
        case .capsule:
            HStack(spacing: 3) {
                icon
                if !text.isEmpty {
                    Text(text)
                }
            }
            .fontWidth(.condensed)
            .fontWeight(.semibold)
            .lineLimit(1)
            .fixedSize()
            .padding(10)
        case .chip:
            HStack(spacing: 4) {
                icon
                    .imageScale(.small)
                    .foregroundStyle(AnyShapeStyle.chipIcon(content: chipContentColor, icon: chipIconColor))
                if !text.isEmpty {
                    Text(text)
                }
            }
            .font(.subheadline)
            .fontWeight(.semibold)
            .fontWidth(.condensed)
            .lineLimit(1)
            .fixedSize()
            .frame(minHeight: 20)
            .padding(.horizontal, text.isEmpty ? 13 : 15)
            .padding(.vertical, 10)
        case .menuItem:
            Label {
                Text(text)
            } icon: {
                icon
            }
        }
    }
}

struct SubscribeCapsuleLabel: View {
    var isSubscribed: Bool
    var isLoading: Bool

    @State private var spinnerDue = false

    var body: some View {
        CapsuleLabel(text: isSubscribed
                        ? String(localized: "subscribed")
                        : String(localized: "subscribe")) {
            if isLoading && spinnerDue {
                ProgressView()
            } else {
                Image(systemName: isSubscribed ? "checkmark" : "plus")
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .task(id: isLoading) {
            spinnerDue = false
            guard isLoading else { return }
            // only show the spinner for slow subscribes, so it doesn't flash
            try? await Task.sleep(for: .milliseconds(300))
            if !Task.isCancelled {
                spinnerDue = true
            }
        }
    }
}

struct CapsuleMenuLabel: View {
    var systemImage: String
    var menuLabel: LocalizedStringKey
    var text: String
    var iconText: String?

    @Environment(\.settingControlStyle) var style
    @Environment(\.compactSettingValues) var compact
    @Environment(\.chipContentColor) var chipContentColor
    @Environment(\.chipIconColor) var chipIconColor

    var body: some View {
        switch style {
        case .capsule:
            VStack(alignment: .leading, spacing: 3) {
                Label(menuLabel, systemImage: systemImage)
                    .labelStyle(.regularSpacing)
                    .font(.system(size: 13))
                    .opacity(0.7)
                Text(text)
                    .fontWidth(.condensed)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
        case .chip:
            HStack(spacing: 4) {
                Group {
                    if compact, let iconText {
                        Text(verbatim: iconText)
                            .fontWeight(.heavy)
                    } else {
                        Image(systemName: systemImage)
                            .imageScale(.small)
                    }
                }
                .foregroundStyle(AnyShapeStyle.chipIcon(content: chipContentColor, icon: chipIconColor))
                if !compact {
                    Text(menuLabel)
                        .foregroundStyle(.secondary)
                }
                Text(text)
            }
            .lineLimit(1)
            .fixedSize()
            .font(.subheadline)
            .fontWeight(.medium)
            .fontWidth(.condensed)
            .padding(.horizontal, 15)
            .padding(.vertical, 10)
        case .menuItem:
            Text(menuLabel)
            Text(text)
            Image(systemName: systemImage)
        }
    }
}

struct RegularSpacingLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon
            configuration.title
        }
    }
}

extension LabelStyle where Self == RegularSpacingLabelStyle {
    static var regularSpacing: RegularSpacingLabelStyle { RegularSpacingLabelStyle() }
}

extension AnyShapeStyle {
    static func chipIcon(content: Color?, icon: Color?) -> AnyShapeStyle {
        if let content { return AnyShapeStyle(content) }
        if let icon { return AnyShapeStyle(icon) }
        return AnyShapeStyle(.tint)
    }
}
