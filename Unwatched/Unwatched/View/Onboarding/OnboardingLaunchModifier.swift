//
//  OnboardingLaunchModifier.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct OnboardingLaunchModifier: ViewModifier {
    @AppStorage(Const.onboardingCompleted) var onboardingCompleted = false
    @AppStorage(Const.onboardingStarted) var onboardingStarted = false
    @AppStorage(Const.settingsSplashShown) var settingsSplashShown = false

    @Environment(NavigationManager.self) var navManager

    func body(content: Content) -> some View {
        @Bindable var navManager = navManager

        content
            .sheet(isPresented: $navManager.showSettingsSplash) {
                SettingsSplashView()
                    .onboardingSheetFrame()
            }
            .onChange(of: navManager.showOnboarding) { wasShown, isShown in
                guard wasShown, !isShown, !onboardingCompleted else { return }
                Task {
                    if let count = await SubscriptionService.getActiveSubscriptionCount().value, count > 0 {
                        onboardingCompleted = true
                    }
                }
            }
            .task {
                guard !onboardingCompleted else {
                    presentSettingsSplashIfNeeded()
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
                    presentSettingsSplashIfNeeded()
                }
            }
    }

    private func presentSettingsSplashIfNeeded() {
        guard !settingsSplashShown else { return }
        if UserDataService.enableRecommendationsForBrowserTabUsersIfNeeded() {
            navManager.searchTabShouldAutoFocus = false
        }
        navManager.presentSettingsSplash()
    }
}

extension View {
    func onboardingOnLaunch() -> some View {
        self.modifier(OnboardingLaunchModifier())
    }
}
