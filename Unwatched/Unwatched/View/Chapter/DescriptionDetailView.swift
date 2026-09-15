//
//  DescriptionDetailView.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

struct DescriptionDetailView: View {
    @AppStorage(Const.themeColor) private var theme: ThemeColor = .defaultTheme
    @Environment(PlayerManager.self) private var player
    @Environment(AppNotificationVM.self) private var appNotificationVM
    @Environment(\.modelContext) private var modelContext
    @State private var hapticToggle = false

    var description: String?

    var body: some View {
        if let description {
            Self.text(for: description, actionColor: theme.darkContrastColor)
                .textRenderer(ActionCapsuleRenderer(color: theme.darkColor))
                .textSelection(.enabled)
                .myTint()
                .environment(\.openURL, OpenURLAction(handler: handleYoutubeAction))
                .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
        }
    }

    // A single Text keeps the description one selectable block; actions are separate so the renderer finds them
    private static func text(for description: String, actionColor: Color) -> Text {
        var interpolation = LocalizedStringKey.StringInterpolation(literalCapacity: 0, interpolationCount: 0)
        for segment in segments(description, actionColor: actionColor) {
            switch segment {
            case .plain(let text):
                interpolation.appendInterpolation(Text(text))
            case .action(let text):
                interpolation.appendInterpolation(Text(text).customAttribute(ActionCapsule()))
            }
        }
        return Text(LocalizedStringKey(stringInterpolation: interpolation))
    }

    // Markdown is parsed per line so emphasis can't run across line breaks
    private static func segments(_ description: String, actionColor: Color) -> [DescriptionSegment] {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        var segments: [DescriptionSegment] = []
        var plain = AttributedString()

        for (index, line) in description.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            if index > 0 {
                plain.append(AttributedString("\n"))
            }
            let text = String(line)
            let parsed = (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
            var copied = parsed.startIndex

            for (link, range) in parsed.runs[\.link] {
                guard let link, UrlService.isYoutubeVideoUrl(url: link) else { continue }
                plain.append(parsed[copied..<range.upperBound])
                copied = range.upperBound
                for action in YoutubeAction.allCases {
                    plain.append(AttributedString(" "))
                    segments.append(.plain(plain))
                    plain = AttributedString()
                    segments.append(.action(actionLink(action, for: link, color: actionColor)))
                }
            }
            plain.append(parsed[copied...])
        }
        segments.append(.plain(plain))
        return segments
    }

    // Menus and alerts presented from behind the menu sheet dismiss it, so the actions are inline links
    private static func actionLink(_ action: YoutubeAction, for url: URL, color: Color) -> AttributedString {
        var components = URLComponents()
        components.scheme = YoutubeAction.scheme
        components.host = action.rawValue
        components.queryItems = [URLQueryItem(name: "url", value: url.absoluteString)]
        var link = AttributedString("\u{00A0}\(String(localized: action.title))\u{00A0}")
        link.link = components.url
        link.font = .footnote
        link.foregroundColor = color
        return link
    }

    private func handleYoutubeAction(_ url: URL) -> OpenURLAction.Result {
        guard url.scheme == YoutubeAction.scheme,
              let host = url.host(),
              let action = YoutubeAction(rawValue: host),
              let urlString = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "url" })?.value,
              let youtubeUrl = URL(string: urlString) else {
            return .systemAction
        }
        hapticToggle.toggle()
        switch action {
        case .play:
            NotificationCenter.default.post(name: .watchInUnwatched, object: nil, userInfo: ["youtubeUrl": youtubeUrl])
        case .queue:
            let task = VideoService.addForeignUrls([youtubeUrl], in: .queue, at: 1)
            player.loadTopmostVideoFromQueue(after: task, modelContext: modelContext, source: .nextUp)
            appNotificationVM.show(.addingVideo)
            notify(.addedVideo, after: task)
        case .inbox:
            let task = VideoService.addForeignUrls([youtubeUrl], in: .inbox)
            notify(AppNotificationData(title: "videoAddedToInbox", icon: Const.checkmarkSF, timeout: 1), after: task)
        }
        return .handled
    }

    private func notify(_ notification: DefaultNotification, after task: Task<(), Error>) {
        notify(notification.notification, after: task)
    }

    private func notify(_ notification: AppNotificationData, after task: Task<(), Error>) {
        Task {
            do {
                try await task.value
                appNotificationVM.show(notification)
            } catch {
                appNotificationVM.show(.error(error))
            }
        }
    }
}

private enum DescriptionSegment {
    case plain(AttributedString)
    case action(AttributedString)
}

private struct ActionCapsule: TextAttribute {}

private struct ActionCapsuleRenderer: TextRenderer {
    let color: Color

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        for line in layout {
            for run in line where run[ActionCapsule.self] != nil {
                let bounds = run.typographicBounds.rect.insetBy(dx: 0, dy: -2.5)
                context.fill(Capsule().path(in: bounds), with: .color(color))
            }
            context.draw(line)
        }
    }
}

private enum YoutubeAction: String, CaseIterable {
    case play, queue, inbox

    static let scheme = "unwatched-description"

    var title: LocalizedStringResource {
        switch self {
        case .play: "play"
        case .queue: "queue"
        case .inbox: "inbox"
        }
    }
}

#Preview {
    DescriptionDetailView(description: Video.getDummy().description)
        .previewEnvironments()
}
