//
//  DeviceIdentity.swift
//  UnwatchedShared
//

import Foundation
import Security

public enum DeviceIdentity {
    private static let fallbackKey = "deviceIdentityFallback"

    public static let id: String = {
        switch readKeychain() {
        case .found(let id):
            return id
        case .notFound:
            let id = UserDefaults.appGroup.string(forKey: fallbackKey) ?? UUID().uuidString
            if addToKeychain(id) {
                return id
            }
            if case .found(let existing) = readKeychain() {
                return existing
            }
            return fallbackId()
        case .unavailable:
            return fallbackId()
        }
    }()

    private enum ReadResult {
        case found(String)
        case notFound
        case unavailable
    }

    private static let baseQuery: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "\(Const.bundleId).deviceIdentity",
        kSecAttrAccount as String: "deviceId",
        kSecAttrSynchronizable as String: false,
        kSecUseDataProtectionKeychain as String: true
    ]

    private static func readKeychain() -> ReadResult {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return .notFound
        }
        guard status == errSecSuccess,
              let data = result as? Data,
              let id = String(data: data, encoding: .utf8) else {
            Log.error("DeviceIdentity: keychain read failed: \(status)")
            return .unavailable
        }
        return .found(id)
    }

    private static func addToKeychain(_ id: String) -> Bool {
        var query = baseQuery
        query[kSecValueData as String] = Data(id.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            Log.error("DeviceIdentity: keychain write failed: \(status)")
        }
        return status == errSecSuccess
    }

    private static func fallbackId() -> String {
        if let id = UserDefaults.appGroup.string(forKey: fallbackKey) {
            return id
        }
        let id = UUID().uuidString
        UserDefaults.appGroup.set(id, forKey: fallbackKey)
        return id
    }
}
