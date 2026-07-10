//
//  AnalyticsQueue.swift
//  Unwatched
//

import Foundation

actor AnalyticsQueue {
    static let shared = AnalyticsQueue()

    private let maxBatchSize = 25
    private let fileUrl: URL

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileUrl = dir.appendingPathComponent("analyticsQueue.json")
    }

    func enqueue(_ event: AnalyticsEvent) async {
        var events = load()
        events.append(event)
        save(events)
        // Buffer normally; events are flushed on background/launch. Flush eagerly only
        // once a full batch has accumulated so a long foreground session stays bounded.
        if events.count >= maxBatchSize {
            await flush()
        }
    }

    func flush() async {
        var events = load()
        while !events.isEmpty {
            let batch = Array(events.prefix(maxBatchSize))
            guard await send(batch) else { return }
            events.removeFirst(batch.count)
            save(events)
        }
    }

    private func send(_ batch: [AnalyticsEvent]) async -> Bool {
        guard let url = URL(string: Credentials.analyticsEndpoint) else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(Credentials.analyticsSecret)", forHTTPHeaderField: "Authorization")
        guard let body = try? JSONEncoder().encode(["events": batch]) else { return false }
        request.httpBody = body

        guard let (_, response) = try? await URLSession.shared.data(for: request) else {
            return false
        }
        return (response as? HTTPURLResponse)?.statusCode == 204
    }

    private func load() -> [AnalyticsEvent] {
        guard let data = try? Data(contentsOf: fileUrl) else { return [] }
        return (try? JSONDecoder().decode([AnalyticsEvent].self, from: data)) ?? []
    }

    private func save(_ events: [AnalyticsEvent]) {
        guard let data = try? JSONEncoder().encode(events) else { return }
        try? data.write(to: fileUrl, options: .atomic)
    }
}
