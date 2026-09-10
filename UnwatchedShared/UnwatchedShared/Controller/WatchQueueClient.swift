//
//  WatchQueueClient.swift
//  UnwatchedShared
//

#if os(watchOS)
import Foundation
import Observation
import WatchConnectivity

public enum WatchQueueRequestError: Error, LocalizedError {
    case notSupported
    case phoneUnreachable
    case emptyReply

    public var errorDescription: String? {
        switch self {
        case .notSupported: String(localized: "watchQueueNotSupported")
        case .phoneUnreachable: String(localized: "watchQueuePhoneUnreachable")
        case .emptyReply: String(localized: "watchQueueEmptyReply")
        }
    }
}

@Observable
public final class WatchQueueClient: NSObject, WCSessionDelegate {
    public static let shared = WatchQueueClient()

    public private(set) var isRequesting = false
    public private(set) var lastError: String?
    public private(set) var lastUpdate: Date? = UserDefaults.standard.object(
        forKey: Const.watchQueueUpdatedDate
    ) as? Date

    /// What the phone is playing, as it last told us.
    public private(set) var remote: WatchRemoteState?

    /// Where the phone's volume landed, stamped so two turns onto the same value still register.
    public private(set) var remoteVolume: WatchVolumeReading?

    /// A speed the wearer has set but the phone has not confirmed yet, so stepping needs no
    /// round trip between taps.
    public private(set) var pendingSpeed: Double?

    public private(set) var totals: WatchQueueSnapshot.Totals? = {
        guard let data = UserDefaults.standard.data(forKey: Const.watchSyncTotals) else { return nil }
        return try? WatchQueueSnapshot.Totals.decoded(data)
    }()

    @ObservationIgnored private var speedTask: Task<Void, Never>?
    @ObservationIgnored private var didActivate = false

    private static let speedDebounce = Duration.milliseconds(400)
    private static let activationAttempts = 50
    private static let staleAfter: TimeInterval = 10 * 60

    public var isReachable: Bool {
        WCSession.isSupported() && WCSession.default.isReachable
    }

    public func activate() {
        guard WCSession.isSupported(), !didActivate else { return }
        didActivate = true
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        if let error {
            Log.error("watch queue: session activation failed: \(error.localizedDescription)")
        }
        // The latest context is waiting whether or not this app was running when it was sent.
        apply(context: session.receivedApplicationContext)
    }

    public func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        apply(context: context)
    }

    public func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let value = WatchRemoteVolume.value(in: message) else { return }
        Task { @MainActor in
            remoteVolume = WatchVolumeReading(value: value, date: .now)
        }
    }

    private func apply(context: [String: Any]) {
        guard let state = WatchRemoteState.decoded(from: context) else { return }
        Task { @MainActor in
            adopt(state)
        }
    }

    /// Every state the phone sends lands here. The theme goes through to `UserDefaults` because
    /// the watch has to draw itself in it at launch, before the phone has been asked anything.
    @MainActor
    private func adopt(_ state: WatchRemoteState) {
        remote = state
        if let theme = state.theme,
           theme != UserDefaults.standard.integer(forKey: Const.themeColor) {
            UserDefaults.standard.set(theme, forKey: Const.themeColor)
        }
    }

    // MARK: - Remote control

    public var remoteSpeed: Double {
        pendingSpeed ?? remote?.speed ?? 1
    }

    /// Shows the new speed at once and sends the last one of a flurry.
    @MainActor
    public func setRemoteSpeed(_ value: Double) {
        pendingSpeed = value
        speedTask?.cancel()
        speedTask = Task { @MainActor in
            try? await Task.sleep(for: Self.speedDebounce)
            guard !Task.isCancelled else { return }
            await send(.setSpeed(value))
            if let pending = pendingSpeed, abs(pending - value) < 0.001 {
                pendingSpeed = nil
            }
        }
    }

    #if DEBUG
    @MainActor
    public func debugSetRemote(_ state: WatchRemoteState) {
        remote = state
    }
    #endif

    @MainActor
    public func refreshRemote() async {
        guard WCSession.isSupported() else { return }
        await waitForActivation()
        await sendRemote([WatchRemoteState.requestKey: true])
    }

    @MainActor
    public func send(_ command: WatchRemoteCommand) async {
        guard WCSession.isSupported(), let message = try? command.message() else { return }
        await waitForActivation()
        await sendRemote(message)
    }

    /// Queued rather than sent: the phone is usually out of range while the watch plays on its own.
    @MainActor
    public func report(_ command: WatchRemoteCommand) {
        guard WCSession.isSupported(), let message = try? command.message() else { return }
        Task { @MainActor in
            await waitForActivation()
            guard WCSession.default.activationState == .activated else { return }
            WCSession.default.transferUserInfo(message)
        }
    }

    /// Every remote message is answered with the phone's state, so acting and drawing are one trip.
    @MainActor
    private func sendRemote(_ message: [String: Any]) async {
        await withCheckedContinuation { continuation in
            WCSession.default.sendMessage(message) { reply in
                let state = WatchRemoteState.decoded(from: reply)
                Task { @MainActor in
                    if let state {
                        self.adopt(state)
                    }
                    continuation.resume()
                }
            } errorHandler: { error in
                Log.error("watch remote: \(error.localizedDescription)")
                continuation.resume()
            }
        }
    }

    // MARK: - Queue snapshot

    @MainActor
    public func requestSnapshot(userInitiated: Bool = true) async {
        guard !isRequesting else { return }
        guard WCSession.isSupported() else {
            lastError = WatchQueueRequestError.notSupported.localizedDescription
            return
        }
        isRequesting = true
        lastError = nil
        defer { isRequesting = false }

        await waitForActivation()

        do {
            let snapshot: WatchQueueSnapshot = try await request(WatchQueueSnapshot.requestKey)
            try WatchQueueStore.replace(with: snapshot)
            lastUpdate = snapshot.createdDate
            UserDefaults.standard.set(snapshot.createdDate, forKey: Const.watchQueueUpdatedDate)
            Log.info("watch queue: imported \(snapshot.items.count) items")
        } catch {
            Log.error("watch queue: request failed: \(error)")
            if userInitiated {
                lastError = error.localizedDescription
            }
        }
    }

    /// The automatic refresh: only if asked for, only while reachable, only once stored rows are stale.
    @MainActor
    public func autoUpdateIfNeeded() async {
        guard UserDefaults.standard.object(forKey: Const.watchQueueFromPhone) as? Bool ?? true else { return }
        if let lastUpdate, Date.now.timeIntervalSince(lastUpdate) < Self.staleAfter {
            return
        }
        // Before reachability is read: the session is unreachable until `activate()` finishes.
        await waitForActivation()
        guard isReachable else { return }
        await requestSnapshot(userInitiated: false)
    }

    /// Drops the snapshot store and the date gating the refresh, so the next launch asks again.
    @MainActor
    public func clearQueue() {
        do {
            try WatchQueueStore.clear()
        } catch {
            Log.error("watch queue: could not clear the snapshot store: \(error)")
        }
        lastUpdate = nil
    }

    @MainActor
    public func requestTotals() async {
        guard WCSession.isSupported() else { return }
        await waitForActivation()
        do {
            let totals: WatchQueueSnapshot.Totals = try await request(
                WatchQueueSnapshot.Totals.requestKey
            )
            self.totals = totals
            UserDefaults.standard.set(try totals.encoded(), forKey: Const.watchSyncTotals)
            Log.info("watch queue: iPhone holds \(totals.total) rows")
        } catch {
            Log.error("watch queue: totals request failed: \(error)")
        }
    }

    @MainActor
    private func waitForActivation() async {
        activate()
        for _ in 0..<Self.activationAttempts {
            if WCSession.default.activationState == .activated { return }
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    private func request<Payload: WatchPayload>(_ requestKey: String) async throws -> Payload {
        try await withCheckedThrowingContinuation { continuation in
            WCSession.default.sendMessage([requestKey: true]) { reply in
                guard let payload = Payload.decoded(from: reply) else {
                    continuation.resume(throwing: WatchQueueRequestError.emptyReply)
                    return
                }
                continuation.resume(returning: payload)
            } errorHandler: { error in
                continuation.resume(
                    throwing: (error as? WCError)?.code == .notReachable
                        ? WatchQueueRequestError.phoneUnreachable
                        : error
                )
            }
        }
    }
}
#endif
