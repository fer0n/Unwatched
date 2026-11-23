//
//  CarPlayNowPlaying.swift
//  Unwatched
//

#if os(iOS)
import CarPlay
import UnwatchedShared

@MainActor
final class CarPlayNowPlaying {
    private weak var interfaceController: CPInterfaceController?
    private weak var speedTemplate: CPListTemplate?
    private var isInstalled = false
    private var shownButtons: Buttons?

    private struct Buttons: Equatable {
        let hasPrevious: Bool
        let hasNext: Bool
        let speed: Double
    }

    init(interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
    }

    func install() {
        isInstalled = true
        updateButtons()
    }

    func uninstall() {
        isInstalled = false
        shownButtons = nil
        CPNowPlayingTemplate.shared.updateNowPlayingButtons([])
    }

    private func updateButtons() {
        guard isInstalled else {
            return
        }
        let buttons = withObservationTracking {
            let player = PlayerManager.shared
            return Buttons(
                hasPrevious: player.currentChapter != nil,
                hasNext: player.nextChapter != nil,
                speed: player.playbackSpeed
            )
        } onChange: { [weak self] in
            Task { @MainActor in self?.updateButtons() }
        }
        guard buttons != shownButtons else {
            return
        }
        shownButtons = buttons

        let previousChapter = Self.button(Const.previousChapterSF) {
            Log.info("carPlay: previous chapter")
            _ = PlayerManager.shared.goToPreviousChapter()
        }
        previousChapter.isEnabled = buttons.hasPrevious
        let nextChapter = Self.button(Const.nextChapterSF) {
            Log.info("carPlay: next chapter")
            _ = PlayerManager.shared.goToNextChapter()
        }
        nextChapter.isEnabled = buttons.hasNext
        let speed = CPNowPlayingImageButton(image: speedImage(buttons.speed)) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.showSpeeds()
            }
        }
        let nextVideo = Self.button(Const.nextVideoSF) {
            Log.info("carPlay: next video")
            PlayerManager.shared.markVideoWatched(showMenu: false, source: .userInteraction)
        }
        CPNowPlayingTemplate.shared.updateNowPlayingButtons([previousChapter, nextChapter, speed, nextVideo])
    }

    private static func button(_ symbol: String, action: @escaping @MainActor () -> Void) -> CPNowPlayingImageButton {
        CPNowPlayingImageButton(image: UIImage(systemName: symbol) ?? UIImage()) { _ in
            MainActor.assumeIsolated(action)
        }
    }

    // MARK: Speed

    // the system's rate button reads the paused rate, 0; CarPlay fits the image to the button's width
    private func speedImage(_ speed: Double) -> UIImage {
        let font = UIFont.systemFont(ofSize: 40, weight: .semibold, width: .compressed)
        let text = NSMutableAttributedString(string: SpeedHelper.formatSpeed(speed), attributes: [.font: font])
        text.append(NSAttributedString(string: "×", attributes: [.font: font.withSize(28)]))
        let size = CGSize(width: ceil(text.size().width), height: ceil(font.capHeight))
        let format = UIGraphicsImageRendererFormat()
        format.scale = interfaceController?.carTraitCollection.displayScale ?? 2
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            text.draw(at: CGPoint(x: 0, y: size.height - font.ascender))
        }
        return image.withRenderingMode(.alwaysTemplate)
    }

    private func showSpeeds() {
        let template = CPListTemplate(title: String(localized: "playbackSpeed"), sections: speedSections())
        speedTemplate = template
        interfaceController?.pushTemplate(template, animated: true, completion: nil)
    }

    // quick speeds first: a list can't open scrolled to the current speed
    private func speedSections() -> [CPListSection] {
        let current = PlayerManager.shared.playbackSpeed
        let recent = CloudStorageSync.shared.string(for: Const.recentPlaybackSpeeds) ?? ""
        let quick = RecentSpeeds.menuSpeeds(recent).map { speedItem($0, current: current) }
        let all = SpeedHelper.remoteSelectable.map { speedItem($0, current: current) }
        let trimSilence = trimSilenceItem().map { [CPListSection(items: [$0])] } ?? []
        return trimSilence + [CPListSection(items: quick), CPListSection(items: all)]
    }

    private func speedItem(_ speed: Double, current: Double) -> CPListItem {
        CPListItem.option(SpeedHelper.label(speed), checked: SpeedHelper.isSame(speed, current)) { [weak self] in
            Log.info("carPlay: speed \(speed)")
            PlayerManager.shared.playbackSpeed = speed
            self?.interfaceController?.popTemplate(animated: true, completion: nil)
        }
    }

    private func trimSilenceItem() -> CPListItem? {
        guard !hidesPremiumEntries else {
            return nil
        }
        let isOn = UserDefaults.standard.bool(forKey: Const.trimSilence)
        let item = CPListItem.option(
            String(localized: "trimSilence"),
            symbol: isOn ? Const.trimSilenceSF : Const.trimSilenceOffSF,
            checked: isOn
        ) { [weak self] in
            Log.info("carPlay: trim silence \(!isOn)")
            PlayerManager.shared.setTrimSilence(!isOn)
            if let self {
                self.speedTemplate?.updateSections(self.speedSections())
            }
        }
        item.isEnabled = PlayerManager.shared.video?.isPodcast == true && (isOn || CloudKeyValueStore.hasPremium)
        return item
    }
}

extension CPListItem {
    @MainActor
    static func option(
        _ text: String,
        symbol: String? = nil,
        checked: Bool,
        action: @escaping @MainActor () -> Void
    ) -> CPListItem {
        let item = CPListItem(
            text: text,
            detailText: nil,
            image: symbol.flatMap { UIImage(systemName: $0) },
            accessoryImage: checked ? UIImage(systemName: "checkmark") : nil,
            accessoryType: .none
        )
        item.handler = { _, completion in
            MainActor.assumeIsolated {
                action()
                completion()
            }
        }
        return item
    }
}
#endif
