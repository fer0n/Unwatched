//
//  SubscribeErrorPopover.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct SubscribeErrorPopover: ViewModifier {
    @Bindable var subManager: SubscribeManager

    func body(content: Content) -> some View {
        content
            .popover(isPresented: Binding(
                get: { subManager.errorMessage != nil },
                set: {
                    if !$0 {
                        subManager.errorMessage = nil
                    }
                }
            )) {
                if let error = subManager.errorMessage {
                    VStack(spacing: 8) {
                        Text("errorOccured")
                            .font(.headline)
                        Text(verbatim: error)
                            .foregroundStyle(.secondary)
                            .font(.body)
                    }
                    .frame(idealWidth: 300, maxWidth: 300)
                    .padding(10)
                    .presentationCompactAdaptation(.popover)
                }
            }
    }
}

extension View {
    func subscribeErrorPopover(_ subManager: SubscribeManager) -> some View {
        modifier(SubscribeErrorPopover(subManager: subManager))
    }
}
