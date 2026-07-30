//
//  SponsorBlockSegmentSetting.swift
//  UnwatchedShared
//

import Foundation

/// How one SponsorBlock segment category is handled: left out entirely,
/// merged in as a chapter, or merged in and skipped automatically during playback.
public enum SponsorBlockSegmentSetting: Int, Codable, CaseIterable, Sendable {
    case nothing = 0
    case show = 1
    case showAndSkip = 2

    public var showsChapters: Bool {
        self != .nothing
    }

    public var skips: Bool {
        self == .showAndSkip
    }
}

/// Minimal subset of `NSUbiquitousKeyValueStore` so settings migration can be tested without iCloud.
public protocol KeyValueStoring: AnyObject {
    func object(forKey aKey: String) -> Any?
    func set(_ anObject: Any?, forKey aKey: String)
    func removeObject(forKey aKey: String)
    func longLong(forKey aKey: String) -> Int64
    func bool(forKey aKey: String) -> Bool
}

extension NSUbiquitousKeyValueStore: KeyValueStoring { }

public extension SponsorBlockSegmentSetting {
    static let sponsorDefault: SponsorBlockSegmentSetting = .show
    static let selfPromoDefault: SponsorBlockSegmentSetting = .nothing

    static var sponsor: SponsorBlockSegmentSetting {
        stored(Const.sponsorSegmentSetting, default: sponsorDefault)
    }

    static var selfPromo: SponsorBlockSegmentSetting {
        stored(Const.selfPromoSegmentSetting, default: selfPromoDefault)
    }

    /// `longLong` can't tell "not set" from `.nothing`, so check for the key first.
    static func stored(
        _ key: String,
        default defaultValue: SponsorBlockSegmentSetting,
        store: KeyValueStoring = NSUbiquitousKeyValueStore.default
    ) -> SponsorBlockSegmentSetting {
        guard store.object(forKey: key) != nil else { return defaultValue }
        return SponsorBlockSegmentSetting(rawValue: Int(store.longLong(forKey: key))) ?? defaultValue
    }

    /// SponsorBlock categories worth requesting: the segment categories the user opted into,
    /// plus SponsorBlock's own chapters when the video brings none of its own.
    static func requestedCategories(
        videoHasChapters: Bool,
        sponsorSetting: SponsorBlockSegmentSetting = SponsorBlockSegmentSetting.sponsor,
        selfPromoSetting: SponsorBlockSegmentSetting = SponsorBlockSegmentSetting.selfPromo
    ) -> [ChapterCategory] {
        var categories = [ChapterCategory]()
        if sponsorSetting.showsChapters {
            categories.append(.sponsor)
        }
        if selfPromoSetting.showsChapters {
            categories.append(.selfpromo)
        }
        if !videoHasChapters {
            categories.append(.chapter)
        }
        return categories
    }

    static func skips(
        _ category: ChapterCategory?,
        sponsorSetting: SponsorBlockSegmentSetting,
        selfPromoSetting: SponsorBlockSegmentSetting
    ) -> Bool {
        switch category {
        case .sponsor: return sponsorSetting.skips
        case .selfpromo: return selfPromoSetting.skips
        default: return false
        }
    }

    /// Folds the former `skipSponsorSegments` toggle into the per-category settings.
    /// Runs once: whoever had auto-skip enabled keeps skipping sponsor segments, everyone
    /// else lands on the new defaults. The legacy key is checked in both stores because a
    /// restored backup from before the iCloud move puts it into `UserDefaults`.
    static func migrateSkipSponsorSegmentsIfNeeded(
        store: KeyValueStoring = NSUbiquitousKeyValueStore.default,
        defaults: UserDefaults = .standard
    ) {
        let legacyValue: Bool? = {
            if store.object(forKey: Const.skipSponsorSegments) != nil {
                return store.bool(forKey: Const.skipSponsorSegments)
            }
            if defaults.object(forKey: Const.skipSponsorSegments) != nil {
                return defaults.bool(forKey: Const.skipSponsorSegments)
            }
            return nil
        }()

        store.removeObject(forKey: Const.skipSponsorSegments)
        defaults.removeObject(forKey: Const.skipSponsorSegments)

        guard let wasSkipping = legacyValue,
              store.object(forKey: Const.sponsorSegmentSetting) == nil else {
            return
        }
        let migrated: SponsorBlockSegmentSetting = wasSkipping ? .showAndSkip : .show
        store.set(Int64(migrated.rawValue), forKey: Const.sponsorSegmentSetting)
    }
}
