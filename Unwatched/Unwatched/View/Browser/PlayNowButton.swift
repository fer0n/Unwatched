//
//  PlayNowButton.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

struct PlayNowButton: View {
    @State private var avm = AddVideoViewModel()
    @State private var isLoading = false
    @State private var hapticToggle = false

    @Environment(PlayerManager.self) var player
    @Environment(NavigationManager.self) var navManager
    @Environment(BrowserManager.self) var browserManager

    var size: Double = 20
    var onDismiss: (() -> Void)?

    var body: some View {
        Button {
            hapticToggle.toggle()
            isLoading = true

            // play now
            Task {
                let task = addTimestampedUrl(at: 0)
                do {
                    try await task.value
                    player.loadTopmostVideoFromQueue(
                        source: .userInteraction,
                        playIfCurrent: true
                    )
                    navManager.handlePlay()
                    onDismiss?()
                    Signal.log("Browser.PlayNow", throttle: .weekly)
                } catch {
                    Log.warning("PlayNowButton: \(error)")
                }
                isLoading = false
            }
        } label: {
            Image(systemName: buttonSymbol)
                .fontWeight(.heavy)
                .frame(width: size, height: size)
                .padding(7)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .myButtonStyle(size)
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
    }

    var buttonSymbol: String {
        if isLoading {
            return "progress.indicator"
        } else {
            return "play.fill"
        }
    }

    func getTimestampedUrl() async -> URL? {
        if let youtubeUrl = browserManager.currentUrl,
           let time = await browserManager.getCurrentTime(),
           let urlWithTime = UrlService.addTimeToUrl(youtubeUrl, time: time) {
            return urlWithTime
        }
        return browserManager.currentUrl
    }

    func addTimestampedUrl(at index: Int = 0) -> Task<Void, Error> {
        return Task {
            if let url = await getTimestampedUrl() {
                await avm.addUrls([url], at: index)
            } else {
                throw VideoError.noVideoUrl
            }
        }
    }
}

private extension View {
    func myButtonStyle(_ size: Double) -> some View {
        self
            #if os(visionOS)
            .viewBackground(size)
            #else
            .apply {
            if #available(iOS 26.0, macOS 26.0, *) {
            $0
            .frame(width: size * 2, height: size * 2)
            .glassEffect(.regular.interactive())
            .foregroundStyle(.primary)
            } else {
            $0.viewBackground(size)
            }
            }
            #endif
            .contentShape(Rectangle())
    }

    func viewBackground(_ size: Double) -> some View {
        self
            .background {
                Circle()
                    .fill(Color.neutralAccentColor)
                    .frame(width: size * 2, height: size * 2)

            }
            .foregroundStyle(Color.backgroundColor)
    }
}

#Preview {
    @Previewable @State var browserManager = BrowserManager()
    browserManager.isVideoUrl = true

    return HStack {
        Spacer()
        PlayNowButton()
            .padding(20)
    }
    .environment(PlayerManager())
    .environment(NavigationManager())
    .environment(browserManager)
}
