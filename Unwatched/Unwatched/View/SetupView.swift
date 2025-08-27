//
//  SetupView.swift
//  Unwatched
//

import SwiftUI
import BackgroundTasks
import SwiftData
import OSLog
import UnwatchedShared

struct CustomAlerter: ViewModifier {
    @State var alerter: Alerter = Alerter()

    func body(content: Content) -> some View {
        content
            .alert(isPresented: $alerter.isShowingAlert) {
                alerter.alert ?? Alert(title: Text(verbatim: ""))
            }
            .environment(alerter)
            .overlay {
                PremiumPopupMessage(dismiss: {
                    alerter.showPremium = false
                })
                .frame(minWidth: 0, idealWidth: 300, maxWidth: 300)
                .fixedSize()
                .padding(.horizontal, 20)
                .padding(.vertical, 30)
                .apply {
                    if #available(iOS 26, macOS 26, *) {
                        $0
                            .glassEffect(in: RoundedRectangle(cornerRadius: 40, style: .continuous))
                            .glassEffectTransition(.materialize )
                    } else {
                        $0
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .shadow(radius: 10)
                            .background(Color.insetBackgroundColor)
                    }
                }
                .opacity(alerter.showPremium ? 1 : 0)
                .scaleEffect(alerter.showPremium ? 1 : 0.9)
                .animation(.default, value: alerter.showPremium)
            }
    }
}

struct PreviewAlerter: View {
    @Environment(Alerter.self) var alerter

    var body: some View {
        Button {
            SheetPositionReader.shared.setDetentMinimumSheet()
            Task {
                alerter.showPremium = true
            }
        } label: {
            Text(verbatim: "Show Alert")
        }
    }
}

#Preview {
    PreviewAlerter()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modifier(CustomAlerter())
        .environment(Alerter())
}

struct SetupView: View {
    @AppStorage(Const.themeColor) var theme: ThemeColor = .teal
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.horizontalSizeClass) var horizontalSizeClass: UserInterfaceSizeClass?
    @Environment(RefreshManager.self) var refresher
    @Environment(\.colorScheme) var colorScheme
    @Environment(PlayerManager.self) var player
    @Environment(\.openWindow) var openWindow

    @State var imageCacheManager = ImageCacheManager.shared
    @State var sheetPos = SheetPositionReader.shared
    @State var navManager = NavigationManager.shared
    @State var undoManager = TinyUndoManager.shared

    var body: some View {
        ContentView()
            .tint(theme.color)
            .environment(sheetPos)
            .watchNotificationHandler()
            .environment(navManager)
            .environment(\.originalColorScheme, colorScheme)
            .environment(imageCacheManager)
            .environment(undoManager)
            .modifier(CustomAlerter())
            .onOpenURL { url in
                Log.info("onOpenURL: \(url)")
                handleDeepLink(url: url)
            }
            #if os(iOS)
            .onChange(of: scenePhase, initial: true) {
                switch scenePhase {
                case .active:
                    NotificationManager.handleNotifications(checkDeferred: true)

                    Log.info("scenePhase: active")
                    Task {
                        refresher.handleAutoBackup()
                        await refresher.handleBecameActive()
                    }
                case .background:
                    Log.info("scenePhase: background")
                    SetupView.handleAppClosed()
                default:
                    break
                }
            }
            #endif
            #if os(macOS)
            .macOSActiveStateChange {
                Log.info("macOSActive: active")
                Task {
                    refresher.handleAutoBackup()
                    await refresher.handleBecameActive()
                }
            } handleResignActive: {
                Log.info("macOSActive: inActive")
                SetupView.handleAppClosed()
            }
            #endif
            .onAppear {
                navManager.openWindow = openWindow
            }
    }

    func handleDeepLink(url: URL) {
        guard let host = url.host else { return }
        switch host {
        case "play":
            // unwatched://play?url=https://www.youtube.com/watch?v=O_0Wn73AnC8
            guard
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                let queryItems = components.queryItems,
                let youtubeUrlString = queryItems.first(where: { $0.name == "url" })?.value,
                let youtubeUrl = URL(string: youtubeUrlString)
            else {
                Log.error("No youtube URL found in deep link: \(url)")
                return
            }
            let userInfo: [AnyHashable: Any] = ["youtubeUrl": youtubeUrl]
            NotificationCenter.default.post(name: .watchInUnwatched, object: nil, userInfo: userInfo)
        default:
            break
        }
    }

    static func handleAppClosed() {
        Log.info("handleAppClosed")
        #if os(iOS)
        NotificationManager.handleNotifications()
        #endif
        Task {
            await saveData()
        }
        RefreshManager.shared.handleBecameInactive()

        #if os(iOS)
        RefreshManager.shared.scheduleVideoRefresh()
        #endif
    }

    static func saveData() async {
        NavigationManager.shared.save()
        SheetPositionReader.shared.save()
        PlayerManager.shared.save()
        await ImageCacheManager.shared.persistCache()
        Log.info("saved state")
    }

    static func setupVideo() {
        Log.info("setupVideo")
        if RefreshManager.shared.consumeTriggerPasteAction() {
            NotificationCenter.default.post(name: .pasteAndWatch, object: nil)
        } else {
            // avoid fetching another video first
            PlayerManager.shared.restoreNowPlayingVideo()
        }
    }
}

#Preview {
    #if os(iOS)
    SetupView()
        .modelContainer(DataProvider.previewContainer)
    #else
    SetupView()
        .modelContainer(DataProvider.previewContainer)
    #endif
}
