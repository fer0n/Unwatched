//
//  MyForm.swift
//  Unwatched
//

import SwiftUI

struct MyForm<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        Form {
            content
        }
        #if os(macOS)
        .formStyle(.grouped)
        .buttonStyle(SettingsRowButtonStyle())
        #endif
        .scrollContentBackground(.hidden)
    }
}

#if os(macOS)
/// macOS gives a `Button` in a grouped `Form` its own bordered capsule, which then sits inset
/// inside the section's own container. These rows are really tappable lines of text, so they
/// take the whole row instead, the way they do on iOS. `NavigationLink` and `Picker` keep their
/// own chrome; `Link`, `Menu`, `ShareLink` and `Button` pick this up.
struct SettingsRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Row(configuration: configuration)
    }

    private struct Row: View {
        @Environment(\.isEnabled) private var isEnabled
        let configuration: ButtonStyleConfiguration

        var body: some View {
            configuration.label
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 3)
                .contentShape(.rect)
                .foregroundStyle(foreground)
                .opacity(configuration.isPressed || !isEnabled ? 0.5 : 1)
        }

        private var foreground: AnyShapeStyle {
            configuration.role == .destructive ? AnyShapeStyle(.red) : AnyShapeStyle(.foreground)
        }
    }
}
#endif
