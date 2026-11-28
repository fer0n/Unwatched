//
//  YouTubePremiumConfirmation.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

/// A "Show & Skip" choice waiting on the YouTube Premium confirmation.
struct PendingSkip: Equatable {
    let id = UUID()
    let apply: () -> Void

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}

/// Skipping sponsor segments requires YouTube Premium: picking a skipping option asks first,
/// and only applies it once confirmed.
private struct YouTubePremiumConfirmation: ViewModifier {
    @CloudStorage(Const.youtubePremium) var youtubePremium: Bool = false
    @Binding var pending: PendingSkip?

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                "youtubePremiumTitle",
                isPresented: Binding(
                    get: { pending != nil },
                    set: { if !$0 { pending = nil } }
                ),
                titleVisibility: .visible,
                presenting: pending
            ) { skip in
                Button("youtubePremiumConfirm") {
                    youtubePremium = true
                    skip.apply()
                }
                Button("youtubePremiumDecline") { }
                Button("cancel", role: .cancel) { }
            } message: { _ in
                Text("considerGettingYoutubePremium")
            }
    }
}

extension View {
    func youtubePremiumConfirmation(_ pending: Binding<PendingSkip?>) -> some View {
        modifier(YouTubePremiumConfirmation(pending: pending))
    }
}
