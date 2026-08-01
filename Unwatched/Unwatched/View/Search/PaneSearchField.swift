//
//  PaneSearchField.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

extension View {
    /// macOS: draws the pane's own search field above this content. No-op elsewhere.
    func paneSearchField(
        text: Binding<String>,
        focused: FocusState<Bool>.Binding,
        prompt: LocalizedStringKey,
        onSubmit: @escaping () -> Void
    ) -> some View {
        #if os(macOS)
        VStack(spacing: 8) {
            PaneSearchField(text: text, focused: focused, prompt: prompt, onSubmit: onSubmit)
                .padding(.horizontal, 12)
            // Claims the leftover height; otherwise a short state re-centres the stack.
            self
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        #else
        self
        #endif
    }

    /// The system search field on the navigation stack. No-op on macOS — see `paneSearchField`.
    func nativeSearchable(
        text: Binding<String>,
        focused: FocusState<Bool>.Binding,
        prompt: LocalizedStringKey,
        onSubmit: @escaping () -> Void
    ) -> some View {
        #if os(macOS)
        self
        #else
        searchable(text: text, prompt: Text(prompt))
            .searchPresentationToolbarBehavior(.avoidHidingContent)
            .searchFocused(focused)
            .onSubmit(of: .search, onSubmit)
        #endif
    }
}

#if os(macOS)
/// The search field for the macOS sidebar pane. `.searchable` renders nothing inside the pane's
/// `TabView`, and hoisting it to the window toolbar would put the field outside the pane.
struct PaneSearchField: View {
    @Binding var text: String
    @FocusState.Binding var focused: Bool
    var prompt: LocalizedStringKey
    var onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.callout)

            TextField(text: $text) {
                Text(prompt)
            }
            .textFieldStyle(.plain)
            .focused($focused)
            .onSubmit {
                // The suggestion list stays up while focused, which would hide the results.
                focused = false
                onSubmit()
            }

            if !text.isEmpty {
                Button {
                    text = ""
                    focused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("clearText")
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 28)
        .background(.quaternary, in: .rect(cornerRadius: 8))
        .contentShape(.rect)
        .onTapGesture {
            focused = true
        }
    }
}
#endif
