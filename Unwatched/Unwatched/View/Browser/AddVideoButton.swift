//
//  AddVideoButton.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

struct AddVideoButton: View {
    @State var avm = AddVideoViewModel()
    @AppStorage(Const.themeColor) var theme = ThemeColor()

    @Environment(PlayerManager.self) var player
    @Environment(NavigationManager.self) var navManager

    @State var showInsert = false
    @State var hapticToggle = false

    @Environment(BrowserManager.self) var browserManager

    var size: Double = 20
    var onDismiss: (() -> Void)?

    var body: some View {
        addVideoButton
            .background {
                ZStack {
                    openInBrowserButton
                        .offset(y: -(2 * 35 + 2 * size))
                    playNowButton
                        .offset(y: -(35 + size))
                }
                .opacity(isVideoUrl ? 1 : 0)
                .animation(.default, value: isVideoUrl)
            }
            .sensoryFeedback(Const.sensoryFeedback, trigger: avm.isDragOver || hapticToggle)
    }

    var openInBrowserButton: some View {
        Button {
            Signal.log("Browser.OpenInBrowser")
            if let youtubeUrl {
                UrlService.open(youtubeUrl)
                onDismiss?()
            }
        } label: {
            Image(systemName: "safari.fill")
                .resizable()
                .scaledToFit()
                .fontWeight(.heavy)
                .frame(width: size * 2, height: size * 2)
                .symbolRenderingMode(.palette)
        }
        .apply {
            if #available(iOS 26.0, macOS 26.0, *) {
                $0
                    .foregroundStyle(.primary, Color.clear)
                    .glassEffect(.regular.interactive())
            } else {
                $0
                    .foregroundStyle(.automaticWhite, Color.neutralAccentColor)
            }
        }
        .buttonStyle(.plain)
    }

    var playNowButton: some View {
        Button {
            hapticToggle.toggle()
            // play now
            let task = addTimestampedUrl(at: 0)

            player.loadTopmostVideoFromQueue(
                after: task,
                source: .userInteraction,
                playIfCurrent: true
            )
            navManager.handlePlay()
            onDismiss?()
            Signal.log("Browser.PlayNow")
        } label: {
            Image(systemName: "play.fill")
                .fontWeight(.heavy)
                .frame(width: size, height: size)
                .padding(7)
        }
        .buttonStyle(.plain)
        .myButtonStyle(size)
    }

    var addVideoButton: some View {
        ZStack {
            // workaround: avoid animation on appear
            if isVideoUrl || isPlaylistUrl || showInsert {
                Button {
                    _ = addTimestampedUrl()
                    Signal.log("Browser.AddVideo")
                } label: {
                    Image(systemName: addVideoSymbol)
                        .fontWeight(.semibold)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: size, height: size)
                        .padding(7)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("dropVideoToQueue")
            }
        }
        .frame(width: size, height: size)
        .myButtonStyle(size)
        .opacity(isVideoUrl || isPlaylistUrl || showInsert ? 1 : 0)
    }

    var addVideoSymbol: String {
        avm.isSuccess == true
            ? "checkmark"
            : avm.isSuccess == false
            ? Const.clearNoFillSF
            : isVideoUrl || isPlaylistUrl || showInsert
            ? Const.queueTopSF
            : avm.isLoading
            ? "ellipsis"
            : "circle.circle"
    }

    var youtubeUrl: URL? {
        browserManager.currentUrl
    }

    var isVideoUrl: Bool {
        browserManager.isVideoUrl
    }

    var isPlaylistUrl: Bool {
        if let url = youtubeUrl {
            return UrlService.getPlaylistIdFromUrl(url) != nil
        }
        return false
    }

    func getTimestampedUrl() async -> URL? {
        if let youtubeUrl,
           let time = await browserManager.getCurrentTime(),
           let urlWithTime = UrlService.addTimeToUrl(youtubeUrl, time: time) {
            return urlWithTime
        }
        return youtubeUrl
    }

    func addTimestampedUrl(at index: Int = 1) -> Task<Void, Error> {
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
            .apply {
                if #available(iOS 26.0, macOS 26.0, *) {
                    $0
                        .frame(width: size * 2, height: size * 2)
                        .glassEffect(.regular.interactive())
                        .foregroundStyle(.primary)
                } else {
                    $0
                        .background {
                            Circle()
                                .fill(Color.neutralAccentColor)
                                .frame(width: size * 2, height: size * 2)

                        }
                        .foregroundStyle(Color.backgroundColor)
                }
            }
            .contentShape(Rectangle())
    }
}

#Preview {
    @Previewable @State var browserManager = BrowserManager()
    browserManager.isVideoUrl = true

    return HStack {
        Spacer()
        AddVideoButton()
            .padding(20)
    }
    .environment(PlayerManager())
    .environment(NavigationManager())
    .environment(browserManager)
}
