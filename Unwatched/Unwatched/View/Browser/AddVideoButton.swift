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
    @Environment(\.dismiss) var dismiss

    @State var showHelp = false
    @State var showInsert = false
    @State var hapticToggle = false

    @Binding var browserManager: BrowserManager

    var size: Double = 20

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
            .foregroundStyle(Color.backgroundColor)
            .sensoryFeedback(Const.sensoryFeedback, trigger: avm.isDragOver || hapticToggle)
    }

    var openInBrowserButton: some View {
        Button {
            if let youtubeUrl {
                UrlService.open(youtubeUrl)
                dismiss()
            }
        } label: {
            Image(systemName: "safari.fill")
                .resizable()
                .scaledToFit()
                .fontWeight(.heavy)
                .frame(width: size * 2, height: size * 2)
                .symbolRenderingMode(.palette)
                .foregroundStyle(.automaticWhite, Color.neutralAccentColor)
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
            dismiss()
        } label: {
            Image(systemName: "play.fill")
                .fontWeight(.heavy)
                .frame(width: size, height: size)
                .padding(7)
        }
        .buttonStyle(.plain)
        .background {
            Circle()
                .fill(Color.neutralAccentColor)
                .frame(width: size * 2, height: size * 2)

        }
    }

    var addVideoButton: some View {
        ZStack {
            Circle()
                .fill(.black.opacity(0.000001))
                .frame(width: backgroundSize, height: backgroundSize)
            Button {
                if isVideoUrl || isPlaylistUrl {
                    _ = addTimestampedUrl()
                } else {
                    showHelp = true
                }
            } label: {
                Image(systemName: avm.isSuccess == true
                        ? "checkmark"
                        : avm.isSuccess == false
                        ? Const.clearNoFillSF
                        : isVideoUrl || isPlaylistUrl || showInsert
                        ? Const.queueTopSF
                        : avm.isLoading
                        ? "ellipsis"
                        : "circle.circle")
                    .fontWeight(.semibold)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: size, height: size)
                    .padding(7)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("dropVideoToQueue")
        }
        .background {
            // Workaround: isDragOver = true get's stuck otherwise
            Circle()
                .fill(avm.isDragOver ? theme.darkColor : Color.neutralAccentColor)
                .frame(width: backgroundSize, height: backgroundSize)
                .animation(.default, value: avm.isDragOver)
        }
        .frame(width: backgroundSize, height: backgroundSize)
        .dropDestination(for: URL.self) { items, _ in
            Task {
                await avm.addUrls(items)
            }
            return true
        } isTargeted: { targeted in
            avm.isDragOver = targeted

            if targeted {
                showInsert = targeted
            } else {
                Task {
                    do {
                        try await Task.sleep(s: 0.5)
                        showInsert = targeted
                    }
                }
            }
        }
        .popover(isPresented: $showHelp) {
            Text("dropVideosTip")
                .padding()
                .presentationCompactAdaptation(.popover)
                .foregroundStyle(Color.neutralAccentColor)
                .fontWeight(.semibold)
        }
        .frame(width: size, height: size)
    }

    var youtubeUrl: URL? {
        browserManager.currentUrl
    }

    var isVideoUrl: Bool {
        browserManager.isVideoUrl
    }

    var backgroundSize: CGFloat {
        avm.isDragOver ? 6 * size : 2 * size
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

#Preview {
    HStack {
        Spacer()
        AddVideoButton(browserManager: .constant(BrowserManager()))
            .padding(20)
    }
    .environment(PlayerManager())
    .environment(NavigationManager())
}
