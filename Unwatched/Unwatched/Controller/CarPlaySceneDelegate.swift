//
//  CarPlaySceneDelegate.swift
//  Unwatched
//

#if os(iOS)
import CarPlay
import CoreMedia
import SwiftData
import UnwatchedShared

@MainActor
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate, CPSessionConfigurationDelegate {
    private struct TabTag: Equatable {
        let id: PersistentIdentifier
        let name: String
        let symbol: String
    }

    private struct TabLayout: Equatable {
        let tags: [TabTag]
        let selection: QueueTagSelection
    }

    private var interfaceController: CPInterfaceController?
    private var sessionConfiguration: CPSessionConfiguration?
    private var nowPlaying: CarPlayNowPlaying?
    private var tabBar: CPTabBarTemplate?
    private var queue: CarPlayQueueList?
    private var tagsTemplate: CPListTemplate?
    private var library: CarPlayLibrary?
    private var selection: QueueTagSelection = .all
    private var pendingTagOptions: [Tag?]?
    private var tabLayout: TabLayout?
    let artwork = CarPlayArtwork()
    private var saveObserver: NSObjectProtocol?
    private var reloadTask: Task<Void, Never>?
    private var connection = 0

    @available(iOS 26.4, *)
    var supportsVideoPlayback: Bool {
        sessionConfiguration?.supportsVideoPlayback == true
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        connection += 1
        self.interfaceController = interfaceController
        artwork.displayScale = interfaceController.carTraitCollection.displayScale
        let sessionConfiguration = CPSessionConfiguration(delegate: self)
        self.sessionConfiguration = sessionConfiguration
        if #available(iOS 26.4, *) {
            Log.info("carPlay: connected, video: \(sessionConfiguration.supportsVideoPlayback)")
        } else {
            Log.info("carPlay: connected")
        }
        let nowPlaying = CarPlayNowPlaying(interfaceController: interfaceController)
        nowPlaying.install()
        self.nowPlaying = nowPlaying

        let library = CarPlayLibrary(scene: self)
        self.library = library
        let tabBar = CPTabBarTemplate(templates: [library.template])
        tabBar.delegate = self
        self.tabBar = tabBar
        interfaceController.setRootTemplate(tabBar, animated: false, completion: nil)

        selection = PlayerManager.shared.playbackTag
        reload()
        if let queue {
            tabBar.select(queue.template)
        }
        observePlayer()
        saveObserver = NotificationCenter.default.addObserver(
            forName: ModelContext.didSave,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.scheduleReload()
            }
        }
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        Log.info("carPlay: disconnected")
        connection += 1
        if let saveObserver {
            NotificationCenter.default.removeObserver(saveObserver)
        }
        saveObserver = nil
        reloadTask?.cancel()
        queue?.cancel()
        queue = nil
        library?.cancel()
        library = nil
        selection = .all
        pendingTagOptions = nil
        tagsTemplate = nil
        tabLayout = nil
        tabBar = nil
        self.interfaceController = nil
        sessionConfiguration = nil
        nowPlaying?.uninstall()
        nowPlaying = nil
    }

    private func observePlayer() {
        let connection = connection
        withObservationTracking {
            let player = PlayerManager.shared
            _ = player.isPlaying
            _ = player.videoEnded
            _ = player.video?.youtubeId
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self, self.connection == connection else {
                    return
                }
                self.scheduleReload()
                self.observePlayer()
            }
        }
    }

    // saves come in bursts
    private func scheduleReload() {
        reloadTask?.cancel()
        reloadTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else {
                return
            }
            self?.reload()
        }
    }

    private func reload() {
        let tags = Self.tags(DataProvider.mainContext)
        if selection.tagId != nil && selection.tag(in: tags) == nil {
            selection = .all
        }
        updateTabs(tags)
        queue?.reload(tags)
        library?.reload()
    }

    // the row's spinner shows until start returns
    func play(_ youtubeId: String, in selection: QueueTagSelection?, completion: @escaping () -> Void) {
        Log.info("carPlay: tapped \(youtubeId)")
        Task {
            defer { completion() }
            let player = PlayerManager.shared
            if player.video?.youtubeId == youtubeId && player.isPlaying {
                player.pause()
                return
            }
            guard let video = VideoService.getVideo(for: youtubeId, modelContext: DataProvider.mainContext) else {
                reload()
                return
            }
            do {
                try await BackgroundPlaybackManager.shared.start(video: video)
                if let selection {
                    player.playbackTag = selection
                }
                Signal.playbackStarted("carPlay")
                if #unavailable(iOS 26.4) {
                    showNowPlaying()
                }
            } catch {
                Log.error("carPlay: playing \(youtubeId) failed — \(error.localizedDescription)")
                showError(error)
            }
        }
    }

    func push(_ template: CPTemplate) {
        interfaceController?.pushTemplate(template, animated: true, completion: nil)
    }

    func pop(_ template: CPTemplate) {
        if interfaceController?.topTemplate === template {
            interfaceController?.popTemplate(animated: true, completion: nil)
        }
    }

    private func showNowPlaying() {
        guard let interfaceController,
              interfaceController.topTemplate !== CPNowPlayingTemplate.shared else {
            return
        }
        interfaceController.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
    }

    private func showError(_ error: Error) {
        let message = (error as? BackgroundPlaybackError).map { String(localized: $0.localizedStringResource) }
            ?? error.localizedDescription
        let alert = CPAlertTemplate(
            titleVariants: [message],
            actions: [
                CPAlertAction(title: String(localized: "ok"), style: .cancel) { [weak self] _ in
                    MainActor.assumeIsolated {
                        self?.interfaceController?.dismissTemplate(animated: true, completion: nil)
                    }
                }
            ]
        )
        interfaceController?.presentTemplate(alert, animated: true, completion: nil)
    }
}

// MARK: Tabs

extension CarPlaySceneDelegate {
    private static func tags(_ context: ModelContext) -> [Tag] {
        (try? context.fetch(FetchDescriptor<Tag>(sortBy: [SortDescriptor(\.order)]))) ?? []
    }

    private static func symbol(of tag: Tag) -> String {
        tag.symbol ?? tag.mode.defaultSymbol
    }

    private func updateTabs(_ tags: [Tag]) {
        let layout = TabLayout(
            tags: tags.map { TabTag(id: $0.persistentModelID, name: $0.name, symbol: Self.symbol(of: $0)) },
            selection: selection
        )
        guard let tabBar, let library, layout != tabLayout else {
            return
        }
        tabLayout = layout
        let current = selection.tag(in: tags)
        let queue = queueList(current)
        if queue !== self.queue {
            self.queue?.cancel()
            self.queue = queue
        }

        var templates: [CPTemplate] = [queue.template]
        if tags.isEmpty {
            tagsTemplate = nil
            pendingTagOptions = nil
        } else {
            let options: [Tag?] = (selection == .all ? [] : [nil]) + tags.filter { $0.persistentModelID != selection.tagId }
            let tagsTemplate = self.tagsTemplate ?? CPListTemplate(title: String(localized: "tags"), sections: [])
            tagsTemplate.tabTitle = String(localized: "tags")
            tagsTemplate.tabImage = UIImage(systemName: Const.tagSF)
            self.tagsTemplate = tagsTemplate
            if tabBar.selectedTemplate === tagsTemplate {
                pendingTagOptions = options
            } else {
                showTagOptions(options)
            }
            templates.append(tagsTemplate)
        }
        templates.append(library.template)
        tabBar.updateTemplates(templates)
    }

    private func queueList(_ tag: Tag?) -> CarPlayQueueList {
        let selection: QueueTagSelection = tag.map { .tag($0.persistentModelID) } ?? .all
        let title = tag?.name ?? String(localized: "queue")
        let reused = queue?.selection == selection && queue?.template.title == title ? queue : nil
        let list = reused ?? CarPlayQueueList(.queue(selection), title: title, scene: self)
        list.template.tabImage = UIImage(systemName: tag.map(Self.symbol) ?? Const.queueTagSF)
        return list
    }

    private func tagItem(_ tag: Tag?) -> CPListItem {
        let option: QueueTagSelection = tag.map { .tag($0.persistentModelID) } ?? .all
        return CPListItem.option(
            tag?.name ?? String(localized: "queue"),
            symbol: tag.map(Self.symbol) ?? Const.queueTagSF,
            checked: false
        ) { [weak self] in
            self?.select(option)
        }
    }

    private func select(_ option: QueueTagSelection) {
        Log.info("carPlay: showing \(option.tagId == nil ? "queue" : "tag")")
        selection = option
        reload()
        if let queue {
            tabBar?.select(queue.template)
        }
        applyPendingTagOptions()
    }

    private func showTagOptions(_ options: [Tag?]) {
        pendingTagOptions = nil
        tagsTemplate?.updateSections([CPListSection(items: options.map(tagItem))])
    }

    private func applyPendingTagOptions() {
        guard let pendingTagOptions, tabBar?.selectedTemplate !== tagsTemplate else {
            return
        }
        showTagOptions(pendingTagOptions)
    }
}

extension CarPlaySceneDelegate: CPTabBarTemplateDelegate {
    func tabBarTemplate(_ tabBarTemplate: CPTabBarTemplate, didSelect selectedTemplate: CPTemplate) {
        applyPendingTagOptions()
    }
}
#endif
