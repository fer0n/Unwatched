//
//  WelcomeBackCard.swift
//  Unwatched
//

import SwiftUI
import OSLog
import UnwatchedShared

struct WelcomeBackCard: View {
    @AppStorage(Const.onboardingCompleted) var onboardingCompleted = false
    @AppStorage(Const.settingsSplashShown) var settingsSplashShown = false
    @AppStorage(Const.themeColor) var theme = ThemeColor()

    let welcomeBack: WelcomeBack
    let onRestored: () -> Void
    let onDismiss: () -> Void

    @State private var syncTurnedOn = false
    @State private var isRestoring = false
    @State private var failure: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if syncTurnedOn {
                syncTurnedOnContent
            } else {
                offerContent
            }
        }
        .padding(16)
        #if os(visionOS)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 22))
        #else
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22))
        #endif
        .padding(.bottom, 16)
        .alert("errorOccured", isPresented: Binding(
            get: { failure != nil },
            set: { if !$0 { failure = nil } }
        )) {
            Button("ok", role: .cancel) { }
        } message: {
            Text(verbatim: failure ?? "")
        }
    }

    @ViewBuilder
    private var offerContent: some View {
        HStack(alignment: .top, spacing: 12) {
            icon
            VStack(alignment: .leading, spacing: 1) {
                title.font(.headline)
                subtitle
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button("close", systemImage: "xmark") {
                welcomeBack.dismiss()
                onDismiss()
            }
            .labelStyle(.iconOnly)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .buttonStyle(.plain)
        }

        body(for: welcomeBack.offer)
            .font(.subheadline)
            .foregroundStyle(.secondary)

        VStack(spacing: 8) {
            switch welcomeBack.offer {
            case .syncWasOn, .otherDevice:
                primaryButton(syncButtonTitle, action: turnOnSync)
                textButton("welcomeBackRestoreInstead", action: restoreLibrary)
            case .sameDevice:
                primaryButton("restoreBackup", action: restoreLibrary)
                Button(action: restoreSettings) {
                    Text("restoreSettingsFromBackup").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
            }
        }
        .disabled(isRestoring)
    }

    private var icon: some View {
        Image(systemName: iconName)
            .font(.title2)
            .foregroundStyle(.white)
            .frame(width: 42, height: 42)
            .background(Color.blue.gradient, in: RoundedRectangle(cornerRadius: 12))
    }

    private var iconName: String {
        switch welcomeBack.offer {
        case .syncWasOn: "icloud.fill"
        case .otherDevice(let kind): kind.systemImage
        case .sameDevice: "clock.arrow.circlepath"
        }
    }

    @ViewBuilder
    private var title: some View {
        switch welcomeBack.offer {
        case .syncWasOn:
            Text("welcomeBackLibraryInIcloud")
        case .otherDevice(let kind):
            if let name = kind.productName {
                Text("welcomeBackLibraryOnDevice \(name)")
            } else {
                Text("welcomeBackLibraryOnOtherDevice")
            }
        case .sameDevice:
            Text("welcomeBackFoundBackup")
        }
    }

    private var subtitle: Text {
        Text("welcomeBackLastBackup \(welcomeBack.backupDeviceName) \(relative(welcomeBack.backupDate))")
    }

    private func body(for offer: WelcomeBack.Offer) -> Text {
        switch offer {
        case .syncWasOn: Text("welcomeBackSyncWasOnBody")
        case .otherDevice: Text("welcomeBackOtherDeviceBody")
        case .sameDevice: Text("welcomeBackSameDeviceBody")
        }
    }

    private var syncButtonTitle: LocalizedStringKey {
        guard case .otherDevice(let kind) = welcomeBack.offer else {
            return "welcomeBackTurnOnSync"
        }
        if let name = kind.productName {
            return "welcomeBackSyncWith \(name)"
        }
        return "welcomeBackSyncWithOtherDevice"
    }

    @ViewBuilder
    private var syncTurnedOnContent: some View {
        Text("welcomeBackSyncTurnedOn")
            .font(.headline)

        VStack(alignment: .leading, spacing: 10) {
            checklistRow("welcomeBackSettingsApplied", done: true)
            checklistRow("welcomeBackSyncOnHere", done: true)
            if case .otherDevice(let kind) = welcomeBack.offer {
                if let name = kind.productName {
                    checklistRow("welcomeBackOtherDeviceNext \(name)", done: false)
                } else {
                    checklistRow("welcomeBackOtherDeviceNextGeneric", done: false)
                }
            }
        }
        .font(.subheadline)

        Text("welcomeBackRestartHint")
            .font(.footnote)
            .foregroundStyle(.secondary)

        primaryButton("restartNow") {
            onboardingCompleted = true
            settingsSplashShown = true
            exit(0)
        }
    }

    private func checklistRow(_ text: LocalizedStringKey, done: Bool) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: done ? "checkmark.circle.fill" : "clock")
                .foregroundStyle(done ? Color.green : Color.secondary)
        }
    }

    private func turnOnSync() {
        welcomeBack.turnOnSync()
        withAnimation { syncTurnedOn = true }
    }

    private func restoreSettings() {
        welcomeBack.restoreSettings()
        onDismiss()
    }

    private func restoreLibrary() {
        isRestoring = true
        Task {
            defer { isRestoring = false }
            do {
                try await welcomeBack.restoreLibrary()
                onRestored()
            } catch {
                fail(error)
            }
        }
    }

    private func fail(_ error: Error) {
        Log.data.error("welcomeBack failed: \(error)")
        Signal.error("backupRestoreFailed")
        failure = error.localizedDescription
    }

    private func primaryButton(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).frame(maxWidth: .infinity)
        }
        .themeProminentButton(theme, capsule: true)
        .controlSize(.large)
    }

    private func textButton(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .padding(.top, 2)
    }

    private func relative(_ date: Date) -> String {
        date.formatted(.relative(presentation: .named))
    }
}
