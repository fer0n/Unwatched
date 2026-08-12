//
//  OnboardingSheetModifier.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct OnboardingSheetModifier: ViewModifier {
    @AppStorage(Const.onboardingCompleted) var onboardingCompleted = false
    @AppStorage(Const.onboardingStarted) var onboardingStarted = false

    @Environment(NavigationManager.self) var navManager

    func body(content: Content) -> some View {
        @Bindable var navManager = navManager

        content
            .sheet(isPresented: $navManager.showOnboarding) {
                OnboardingView()
                    #if os(macOS) || os(visionOS)
                    .frame(minWidth: 450, minHeight: 650)
                #endif
            }
            .task {
                guard !onboardingCompleted else {
                    return
                }
                guard !onboardingStarted else {
                    // quit before finishing: pick it up again
                    navManager.presentOnboarding()
                    return
                }
                guard let count = await SubscriptionService.getActiveSubscriptionCount().value else {
                    // unknown: leave it to the next launch rather than onboard an install that
                    // may well have subscriptions
                    return
                }
                if count == 0 {
                    navManager.presentOnboarding()
                } else {
                    onboardingCompleted = true
                }
            }
    }
}

extension View {
    func onboardingSheet() -> some View {
        self.modifier(OnboardingSheetModifier())
    }
}
