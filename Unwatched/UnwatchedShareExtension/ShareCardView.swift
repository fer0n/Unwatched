//
//  ShareCardView.swift
//  UnwatchedShareExtension
//
//  Lets the user pick where a shared YouTube link goes, then shows the result while the
//  actual work happens in-process (no hand-off to the main app).
//

import SwiftUI
import UnwatchedShared

struct ShareCardView: View {
    @Bindable var model: ShareCardModel
    var imageCacheManager: ImageCacheManager
    var onSelect: (ShareAction) -> Void
    var onConfirmRemember: (Bool) -> Void
    var onSetAutoAction: (ShareExtensionActionSetting) -> Void
    var onToggleSubscribe: () -> Void

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Matches the video detail sheet's background (Color.backgroundColor in the main
            // app) — that named asset lives only in the main app's own asset catalog and can't
            // resolve from the extension's bundle, so its exact values are reproduced below.
            .background(Color.shareSheetBackground)
            .environment(imageCacheManager)
            .animation(.snappy(duration: 0.28), value: model.state)
            .alert(
                "shareExtensionRememberTitle",
                isPresented: Binding(
                    get: { model.pendingRememberPrompt != nil },
                    set: { if !$0 { model.pendingRememberPrompt = nil } }
                )
            ) {
                Button("shareExtensionRememberDecline", role: .cancel) { onConfirmRemember(false) }
                Button("shareExtensionRememberConfirm") { onConfirmRemember(true) }
            } message: {
                Text("shareExtensionRememberMessage")
            }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .choosing(.video):
            ScrollView {
                if let videoPreview = model.videoPreview {
                    videoPreviewContent(for: videoPreview)
                }
            }
            .safeAreaBar(edge: .bottom) {
                actionButtonsPanel(for: .video)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }
        case .choosing(.channel):
            VStack(spacing: 0) {
                Spacer(minLength: 12)
                if let channelPreview = model.channelPreview {
                    channelPreviewContent(for: channelPreview)
                } else {
                    channelPreviewSkeleton
                }
                Spacer(minLength: 12)
            }
        case .working(let message):
            statusView(showsSpinner: true, message: Text(message))
        case .done(let message):
            statusView(systemImage: "checkmark.circle.fill", tint: .green, message: Text(message))
        case .error(let message):
            statusView(systemImage: "xmark.circle.fill", tint: .red, message: Text(message))
        case .noLink:
            disabledPreview(message: Text("No link found"))
        case .notYouTube:
            disabledPreview(message: Text("Not a YouTube link"))
        }
    }

    /// A row of individually-glassed icon buttons, same Liquid Glass look as the video detail
    /// sheet's bottom toolbar.
    func actionButtonsPanel(for kind: ShareLinkKind) -> some View {
        HStack {
            ForEach(ShareAction.actions(for: kind), id: \.self) { action in
                Button {
                    onSelect(action)
                } label: {
                    Image(systemName: model.loadingAction == action ? "progress.indicator" : action.systemImage)
                        .font(.headline)
                        .frame(width: 60, height: 60)
                        .contentTransition(.symbolEffect(.replace))
                }
                .shareSheetGlassEffect(in: .circle)
                .accessibilityLabel(action.title)
                .disabled(model.loadingAction != nil)
            }
            if kind == .video {
                shareActionSettingsButton
            }
        }
        .foregroundStyle(.primary)
    }

    /// Same options as the main app's "Share Extension Action" setting (`GeneralSettingsView`) —
    /// picking one here writes straight to the setting the app reads, so both surfaces always
    /// agree on what's currently selected. The explanatory text that would normally be a footer
    /// becomes the section's title instead, since `Menu` has no footer of its own.
    private var shareActionSettingsButton: some View {
        Menu {
            Section("shareExtensionRememberInfo") {
                ForEach(ShareExtensionActionSetting.allCases, id: \.self) { setting in
                    Button {
                        onSetAutoAction(setting)
                    } label: {
                        HStack {
                            Text(setting.title)
                            if ShareExtensionSettings.action == setting {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.headline)
                .frame(width: 60, height: 60)
        }
        .shareSheetGlassEffect(in: .circle)
        .accessibilityLabel("moreOptions")
        .disabled(model.loadingAction != nil)
    }

    /// Shown once we know the shared item isn't something we can act on: the video-shaped skeleton
    /// and (non-functional) action buttons stay visible but dimmed/disabled, with a floating glass
    /// message explaining why, rather than replacing the screen with a different layout entirely.
    private func disabledPreview(message: Text) -> some View {
        ZStack {
            ScrollView {
                skeletonVideoPreview
            }
            .safeAreaBar(edge: .bottom) {
                actionButtonsPanel(for: .video)
            }
            .disabled(true)
            .opacity(0.35)

            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                    .symbolRenderingMode(.hierarchical)
                message
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .shareSheetGlassEffect(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, 40)
        }
    }

    private func statusView(
        systemImage: String? = nil,
        tint: Color = .primary,
        showsSpinner: Bool = false,
        message: Text
    ) -> some View {
        VStack(spacing: 14) {
            if showsSpinner {
                ProgressView()
                    .controlSize(.large)
            } else if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(tint)
                    .symbolRenderingMode(.hierarchical)
                    .transition(.scale.combined(with: .opacity))
            }
            message
                .font(.headline)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Choosing") {
    let model = ShareCardModel()
    model.state = .choosing(.video)
    model.videoPreview = SendableVideo(
        youtubeId: "dQw4w9WgXcQ",
        title: "Some Video Title That Might Wrap to Two Lines",
        url: URL(string: "https://youtu.be/dQw4w9WgXcQ"),
        thumbnailUrl: URL(string: "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg"),
        duration: 212,
        videoDescription: String(repeating: "This is a preview description. ", count: 20)
    )
    return ShareCardView(
        model: model,
        imageCacheManager: ImageCacheManager(),
        onSelect: { _ in },
        onConfirmRemember: { _ in },
        onSetAutoAction: { _ in },
        onToggleSubscribe: {}
    )
}

#Preview("Channel") {
    let model = ShareCardModel()
    model.state = .choosing(.channel)
    model.channelPreview = SendableSubscription(
        title: "Some Channel Name",
        youtubeChannelId: "UC123",
        thumbnailUrl: URL(string: "https://yt3.ggpht.com/ytc/AIdro_nonexistent=s176-c-k-c0x00ffffff-no-rj")
    )
    return ShareCardView(
        model: model,
        imageCacheManager: ImageCacheManager(),
        onSelect: { _ in },
        onConfirmRemember: { _ in },
        onSetAutoAction: { _ in },
        onToggleSubscribe: {}
    )
}

#Preview("Error") {
    let model = ShareCardModel()
    model.state = .error("Something went wrong")
    return ShareCardView(
        model: model,
        imageCacheManager: ImageCacheManager(),
        onSelect: { _ in },
        onConfirmRemember: { _ in },
        onSetAutoAction: { _ in },
        onToggleSubscribe: {}
    )
}

#Preview("Not a YouTube link") {
    let model = ShareCardModel()
    model.state = .notYouTube
    return ShareCardView(
        model: model,
        imageCacheManager: ImageCacheManager(),
        onSelect: { _ in },
        onConfirmRemember: { _ in },
        onSetAutoAction: { _ in },
        onToggleSubscribe: {}
    )
}
