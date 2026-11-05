//
//  DescriptionTextView.swift
//  Unwatched
//

#if os(iOS)
import SwiftUI
import UIKit

/// A selectable SwiftUI Text turns a long press on a link into a text selection; UITextView shows the link menu
struct DescriptionTextView: UIViewRepresentable {
    let description: String
    let linkColor: Color
    let actionColor: Color
    let capsuleColor: Color

    func makeUIView(context: Context) -> ActionCapsuleTextView {
        let view = ActionCapsuleTextView()
        view.isEditable = false
        view.isScrollEnabled = false
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        // colored per range, so action links keep their own color
        view.linkTextAttributes = [:]
        view.delegate = context.coordinator
        return view
    }

    func updateUIView(_ view: ActionCapsuleTextView, context: Context) {
        let environment = context.environment
        context.coordinator.openURL = environment.openURL
        let key = Content(
            description: description,
            linkColor: linkColor,
            actionColor: actionColor,
            capsuleColor: capsuleColor,
            colorScheme: environment.colorScheme,
            dynamicTypeSize: environment.dynamicTypeSize,
            legibilityWeight: environment.legibilityWeight
        )
        guard context.coordinator.content != key else { return }
        context.coordinator.content = key

        let traits = UITraitCollection { traits in
            traits.preferredContentSizeCategory = UIContentSizeCategory(key.dynamicTypeSize)
            traits.legibilityWeight = key.legibilityWeight == .bold ? .bold : .regular
        }
        let link = Self.uiColor(linkColor, in: environment)
        view.attributedText = Self.attributedText(
            description,
            fonts: Fonts(
                body: .preferredFont(forTextStyle: .body, compatibleWith: traits),
                action: .preferredFont(forTextStyle: .footnote, compatibleWith: traits)
            ),
            linkColor: link,
            actionColor: Self.uiColor(actionColor, in: environment)
        )
        view.tintColor = link
        view.capsuleColor = Self.uiColor(capsuleColor, in: environment)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: ActionCapsuleTextView, context: Context) -> CGSize? {
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil }
        // like Text, an unspecified width lays out unwrapped
        let fitting = CGSize(width: width ?? .greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        let size = uiView.sizeThatFits(fitting)
        return CGSize(width: width ?? size.width, height: size.height)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private static func uiColor(_ color: Color, in environment: EnvironmentValues) -> UIColor {
        UIColor(cgColor: color.resolve(in: environment).cgColor)
    }

    struct Content: Equatable {
        let description: String
        let linkColor: Color
        let actionColor: Color
        let capsuleColor: Color
        let colorScheme: ColorScheme
        let dynamicTypeSize: DynamicTypeSize
        let legibilityWeight: LegibilityWeight?
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var openURL: OpenURLAction?
        var content: Content?

        // taps go through SwiftUI's openURL so the description's own handler sees them
        func textView(
            _ textView: UITextView,
            primaryActionFor textItem: UITextItem,
            defaultAction: UIAction
        ) -> UIAction? {
            guard case .link(let url) = textItem.content, let openURL else { return defaultAction }
            return UIAction { _ in openURL(url) }
        }

        func textView(
            _ textView: UITextView,
            menuConfigurationFor textItem: UITextItem,
            defaultMenu: UIMenu
        ) -> UITextItem.MenuConfiguration? {
            if case .link(let url) = textItem.content, url.scheme == YoutubeAction.scheme {
                return nil
            }
            return UITextItem.MenuConfiguration(menu: defaultMenu)
        }
    }
}

extension DescriptionTextView {
    private struct Fonts {
        let body: UIFont
        let action: UIFont
    }

    private static func attributedText(
        _ description: String,
        fonts: Fonts,
        linkColor: UIColor,
        actionColor: UIColor
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for segment in DescriptionDetailView.segments(description) {
            switch segment {
            case .plain(let text):
                for run in text.runs {
                    var attributes: [NSAttributedString.Key: Any] = [
                        .font: font(fonts.body, for: run.inlinePresentationIntent),
                        .foregroundColor: UIColor.label
                    ]
                    if let link = run.link {
                        attributes[.link] = link
                        attributes[.foregroundColor] = linkColor
                    }
                    if run.inlinePresentationIntent?.contains(.strikethrough) == true {
                        attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
                    }
                    let string = String(text[run.range].characters)
                    result.append(NSAttributedString(string: string, attributes: attributes))
                }
            case .action(let text):
                var attributes: [NSAttributedString.Key: Any] = [
                    .font: fonts.action,
                    .foregroundColor: actionColor,
                    .descriptionAction: true
                ]
                attributes[.link] = text.runs.first?.link
                result.append(NSAttributedString(string: String(text.characters), attributes: attributes))
            }
        }
        return result
    }

    private static func font(_ base: UIFont, for intent: InlinePresentationIntent?) -> UIFont {
        guard let intent else { return base }
        if intent.contains(.code) {
            return .monospacedSystemFont(ofSize: base.pointSize, weight: .regular)
        }
        var traits = base.fontDescriptor.symbolicTraits
        if intent.contains(.stronglyEmphasized) {
            traits.insert(.traitBold)
        }
        if intent.contains(.emphasized) {
            traits.insert(.traitItalic)
        }
        guard let descriptor = base.fontDescriptor.withSymbolicTraits(traits) else { return base }
        return UIFont(descriptor: descriptor, size: base.pointSize)
    }
}

private extension NSAttributedString.Key {
    static let descriptionAction = NSAttributedString.Key("unwatchedDescriptionAction")
}

final class ActionCapsuleTextView: UITextView {
    var capsuleColor: UIColor = .clear {
        didSet { capsuleLayer.fillColor = capsuleColor.cgColor }
    }
    override var attributedText: NSAttributedString! {
        didSet {
            capsuleSize = nil
            setNeedsLayout()
        }
    }
    // Deselecting moves the closing edit menu to the empty selection at the top of the text before it fades out
    override var selectedTextRange: UITextRange? {
        get { super.selectedTextRange }
        set {
            if newValue?.isEmpty ?? true {
                for case let menu as UIEditMenuInteraction in interactions {
                    menu.dismissMenu()
                }
            }
            super.selectedTextRange = newValue
        }
    }
    private let capsuleLayer = CAShapeLayer()
    private var capsuleSize: CGSize?

    init() {
        super.init(frame: .zero, textContainer: nil)
        capsuleLayer.actions = ["path": NSNull(), "bounds": NSNull(), "position": NSNull(), "fillColor": NSNull()]
        layer.insertSublayer(capsuleLayer, at: 0)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard capsuleSize != bounds.size else { return }
        capsuleSize = bounds.size
        capsuleLayer.frame = bounds
        capsuleLayer.path = capsulePath()
    }

    private func capsulePath() -> CGPath {
        let path = CGMutablePath()
        guard let layoutManager = textLayoutManager,
              let content = layoutManager.textContentManager,
              let text = attributedText else { return path }
        let padding = DescriptionDetailView.actionCapsulePadding
        text.enumerateAttribute(.descriptionAction, in: NSRange(location: 0, length: text.length)) { value, range, _ in
            guard value != nil,
                  let font = text.attribute(.font, at: range.location, effectiveRange: nil) as? UIFont,
                  let start = content.location(content.documentRange.location, offsetBy: range.location),
                  let end = content.location(start, offsetBy: range.length),
                  let textRange = NSTextRange(location: start, end: end) else { return }
            layoutManager.ensureLayout(for: textRange)
            layoutManager.enumerateTextSegments(in: textRange, type: .standard, options: []) { _, frame, baseline, _ in
                guard frame.width > 0 else { return true }
                let capsule = CGRect(
                    x: frame.minX,
                    y: frame.minY + baseline - font.ascender - padding,
                    width: frame.width,
                    height: font.ascender - font.descender + 2 * padding
                )
                path.addPath(UIBezierPath(roundedRect: capsule, cornerRadius: capsule.height / 2).cgPath)
                return true
            }
        }
        return path
    }
}
#endif
