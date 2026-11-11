//
//  DescriptionDetailView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct DescriptionDetailView: View {
    @AppStorage(Const.themeColor) private var theme: ThemeColor = .defaultTheme
    @Environment(NavigationManager.self) private var navManager

    var description: String?

    var body: some View {
        if let description {
            descriptionText(description)
                .myTint()
                .environment(\.openURL, OpenURLAction(handler: handleDescriptionLink))
        }
    }

    @ViewBuilder
    private func descriptionText(_ description: String) -> some View {
        #if os(iOS)
        DescriptionTextView(
            description: description,
            linkColor: theme.color,
            actionColor: theme.darkContrastColor,
            capsuleColor: theme.darkColor
        )
        #else
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(Self.chunks(of: description).enumerated()), id: \.offset) { _, chunk in
                Self.text(for: chunk, actionColor: theme.darkContrastColor)
                    .textRenderer(ActionCapsuleRenderer(color: theme.darkColor))
            }
        }
        .textSelection(.enabled)
        #endif
    }

    // a very tall Text with a custom renderer draws nothing
    private static func chunks(of description: String) -> [String] {
        var chunks: [String] = []
        var current: [Substring] = []
        var length = 0
        for line in description.split(separator: "\n", omittingEmptySubsequences: false) {
            if !current.isEmpty, length + line.count > chunkLength {
                var carried: [Substring] = []
                while current.count > 1, current.last?.isEmpty == true {
                    carried.append(current.removeLast())
                }
                chunks.append(current.joined(separator: "\n"))
                current = carried
                length = carried.count
            }
            current.append(line)
            length += line.count + 1
        }
        chunks.append(current.joined(separator: "\n"))
        return chunks
    }

    private static let chunkLength = 1500

    nonisolated static let actionCapsulePadding: CGFloat = 2.5

    // Actions are separate so the renderer finds them
    private static func text(for description: String, actionColor: Color) -> Text {
        var interpolation = LocalizedStringKey.StringInterpolation(literalCapacity: 0, interpolationCount: 0)
        for segment in segments(description) {
            switch segment {
            case .plain(let text):
                interpolation.appendInterpolation(Text(text))
            case .action(let text):
                interpolation.appendInterpolation(
                    Text(text).font(.footnote).foregroundColor(actionColor).customAttribute(ActionCapsule())
                )
            }
        }
        return Text(LocalizedStringKey(stringInterpolation: interpolation))
    }

    // Markdown is parsed per line so emphasis can't run across line breaks
    static func segments(_ description: String) -> [DescriptionSegment] {
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
                guard let link, DescriptionLinkTarget(link) != nil else { continue }
                plain.append(parsed[copied..<range.upperBound])
                copied = range.upperBound
                plain.append(AttributedString(" "))
                segments.append(.plain(plain))
                plain = AttributedString()
                segments.append(.action(openLink(for: link)))
            }
            plain.append(parsed[copied...])
        }
        segments.append(.plain(plain))
        return segments
    }

    private static func openLink(for url: URL) -> AttributedString {
        var components = URLComponents()
        components.scheme = YoutubeAction.scheme
        components.queryItems = [URLQueryItem(name: "url", value: url.absoluteString)]
        var link = AttributedString("\u{00A0}\u{00A0}\u{2192}\u{00A0}\u{00A0}")
        link.link = components.url
        return link
    }

    private func handleDescriptionLink(_ url: URL) -> OpenURLAction.Result {
        guard url.scheme == YoutubeAction.scheme,
              let urlString = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "url" })?.value,
              let link = URL(string: urlString),
              let target = DescriptionLinkTarget(link) else {
            return .systemAction
        }
        // revealMenu has its own haptic
        switch target {
        case .video: navManager.openVideoDetail(for: link)
        case .subscription: navManager.openSubscriptionDetail(for: link)
        }
        return .handled
    }
}

enum DescriptionSegment {
    case plain(AttributedString)
    case action(AttributedString)
}

private struct ActionCapsule: TextAttribute {}

private struct ActionCapsuleRenderer: TextRenderer {
    let color: Color

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        for line in layout {
            for run in line where run[ActionCapsule.self] != nil {
                let bounds = run.typographicBounds.rect.insetBy(dx: 0, dy: -DescriptionDetailView.actionCapsulePadding)
                context.fill(Capsule().path(in: bounds), with: .color(color))
            }
            context.draw(line)
        }
    }
}

enum YoutubeAction {
    static let scheme = "unwatched-description"
}

#Preview {
    DescriptionDetailView(description: Video.getDummy().description)
        .previewEnvironments()
}
